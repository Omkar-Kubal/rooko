import {
  createPrivateKey,
  createPublicKey,
  createSign,
  createVerify,
} from 'node:crypto';

export const MAX_ENVELOPE_BYTES = 512 * 1024;
export const MAX_ENTRIES = 10_000;
export const MAX_VALIDITY_DAYS = 30;

const allowedPackages = new Set([
  'com.google.android.youtube',
  'com.instagram.android',
]);
const versionPattern = /^[A-Za-z0-9.+_-]{1,64}$/;
const profilePattern = /^[a-z0-9][a-z0-9._-]{0,63}$/;
const allowedStatuses = new Set(['catalogued', 'supported', 'disabled']);
const allowedPayloadKeysV1 = new Set([
  'schemaVersion',
  'sequence',
  'issuedAtEpochSeconds',
  'expiresAtEpochSeconds',
  'entries',
]);
const allowedPayloadKeysV2 = new Set([...allowedPayloadKeysV1, 'profiles']);
const allowedEntryKeys = new Set([
  'packageName',
  'versionName',
  'status',
  'profileId',
  'sourceUrl',
  'validation',
]);
const allowedValidationKeys = new Set([
  'reportId',
  'transitionCases',
  'stationaryCases',
  'deviceFamilies',
  'precisionPercent',
  'recallPercent',
  'stationaryRepeats',
]);
const allowedProfileKeys = new Set([
  'profileId',
  'packageName',
  'strategyId',
  'feedMarkerViewIds',
  'transitionViewIds',
  'identityStrategy',
  'identityNodeViewId',
]);
const allowedIdentityStrategies = new Set([
  'stable_opaque_accessibility_token',
  'structural_node_pair',
  'bounded_transition_fingerprint',
]);

export class RegistryPayloadError extends Error {
  constructor(message) {
    super(message);
    this.name = 'RegistryPayloadError';
  }
}

function fail(message) {
  throw new RegistryPayloadError(message);
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function hasOnlyKeys(record, allowed, location) {
  for (const key of Object.keys(record)) {
    if (!allowed.has(key)) fail(`${location} contains unknown field: ${key}`);
  }
}

function requireInteger(record, key, location) {
  const value = record[key];
  if (!Number.isSafeInteger(value)) fail(`${location}.${key} must be a safe integer`);
  return value;
}

function checkNoDuplicateObjectKeys(jsonText) {
  let index = 0;

  function skipWhitespace() {
    while (/[\t\n\r ]/.test(jsonText[index] ?? '')) index += 1;
  }

  function parseString() {
    const start = index;
    if (jsonText[index] !== '"') throw new Error('Expected JSON string');
    index += 1;
    while (index < jsonText.length) {
      const character = jsonText[index];
      if (character === '"') {
        index += 1;
        return JSON.parse(jsonText.slice(start, index));
      }
      if (character === '\\') index += 1;
      index += 1;
    }
    throw new Error('Unterminated JSON string');
  }

  function parseObject() {
    index += 1;
    skipWhitespace();
    const keys = new Set();
    if (jsonText[index] === '}') {
      index += 1;
      return;
    }
    while (index < jsonText.length) {
      skipWhitespace();
      const key = parseString();
      if (keys.has(key)) fail(`Duplicate JSON object key: ${key}`);
      keys.add(key);
      skipWhitespace();
      if (jsonText[index] !== ':') throw new Error('Expected colon after JSON object key');
      index += 1;
      parseValue();
      skipWhitespace();
      if (jsonText[index] === '}') {
        index += 1;
        return;
      }
      if (jsonText[index] !== ',') throw new Error('Expected comma in JSON object');
      index += 1;
    }
    throw new Error('Unterminated JSON object');
  }

  function parseArray() {
    index += 1;
    skipWhitespace();
    if (jsonText[index] === ']') {
      index += 1;
      return;
    }
    while (index < jsonText.length) {
      parseValue();
      skipWhitespace();
      if (jsonText[index] === ']') {
        index += 1;
        return;
      }
      if (jsonText[index] !== ',') throw new Error('Expected comma in JSON array');
      index += 1;
    }
    throw new Error('Unterminated JSON array');
  }

  function parseValue() {
    skipWhitespace();
    if (jsonText[index] === '{') return parseObject();
    if (jsonText[index] === '[') return parseArray();
    if (jsonText[index] === '"') {
      parseString();
      return;
    }
    const tokenStart = index;
    while (index < jsonText.length && !/[\t\n\r ,}\]]/.test(jsonText[index])) index += 1;
    if (tokenStart === index) throw new Error('Expected JSON value');
  }

  parseValue();
  skipWhitespace();
  if (index !== jsonText.length) throw new Error('Trailing JSON content');
}

function normalizeBundledProfiles(profiles) {
  if (!Array.isArray(profiles)) fail('bundledProfiles must be an array');
  const ids = new Set();
  for (const profile of profiles) {
    if (!isRecord(profile) || Object.keys(profile).length !== 2 ||
      typeof profile.packageName !== 'string' || typeof profile.profileId !== 'string') {
      fail('Each bundled profile must contain only packageName and profileId');
    }
    if (!allowedPackages.has(profile.packageName) || !profilePattern.test(profile.profileId)) {
      fail('Bundled profile manifest contains an invalid package or profile ID');
    }
    const key = `${profile.packageName}\0${profile.profileId}`;
    if (ids.has(key)) fail(`Duplicate bundled profile: ${profile.packageName}/${profile.profileId}`);
    ids.add(key);
  }
  return ids;
}

export function buildRegistryPayload(catalogBytes, {
  sequence,
  previousSequence = 0,
  nowMillis = Date.now(),
  validityDays = MAX_VALIDITY_DAYS,
  bundledProfiles = [],
} = {}) {
  if (!(catalogBytes instanceof Uint8Array) || catalogBytes.byteLength === 0 ||
    catalogBytes.byteLength > MAX_ENVELOPE_BYTES) {
    fail('Catalog must be non-empty UTF-8 JSON no larger than 512 KiB');
  }
  let catalogText;
  try {
    catalogText = new TextDecoder('utf-8', { fatal: true }).decode(catalogBytes);
  } catch (error) {
    fail(`Catalog must be valid UTF-8: ${error.message}`);
  }
  checkNoDuplicateObjectKeys(catalogText);

  let catalog;
  try {
    catalog = JSON.parse(catalogText);
  } catch (error) {
    fail(`Catalog is not valid JSON: ${error.message}`);
  }
  if (!isRecord(catalog)) fail('Catalog root must be an object');
  hasOnlyKeys(catalog, new Set(['schemaVersion', 'entries', 'profiles']), 'Catalog');
  if (![1, 2].includes(catalog.schemaVersion) || !Array.isArray(catalog.entries) ||
    (catalog.schemaVersion === 2 && !Array.isArray(catalog.profiles))) {
    fail('Catalog must contain schemaVersion 1 or 2 and the corresponding arrays');
  }
  if (!Number.isSafeInteger(sequence) || sequence <= previousSequence || sequence <= 0) {
    fail(`sequence must be positive and greater than ${previousSequence}`);
  }
  if (!Number.isSafeInteger(previousSequence) || previousSequence < 0) {
    fail('previousSequence must be a non-negative safe integer');
  }
  if (!Number.isSafeInteger(validityDays) || validityDays < 1 || validityDays > MAX_VALIDITY_DAYS) {
    fail(`validityDays must be between 1 and ${MAX_VALIDITY_DAYS}`);
  }
  if (!Number.isSafeInteger(nowMillis) || nowMillis <= 0) fail('nowMillis must be positive');

  const issuedAtEpochSeconds = Math.floor(nowMillis / 1000);
  const catalogEntries = catalog.entries.map((entry, index) => {
    if (!isRecord(entry)) fail(`entries[${index}] must be an object`);
    const hasValidation = Object.hasOwn(entry, 'validation');
    const validation = entry.status === 'supported'
      ? validateVersionEvidence(entry.validation, `entries[${index}].validation`)
      : null;
    if (entry.status !== 'supported' && hasValidation) {
      fail(`entries[${index}].validation is only allowed for supported versions`);
    }
    const { validation: _validation, ...publicEntry } = entry;
    return catalog.schemaVersion === 2 && validation
      ? { ...publicEntry, validation }
      : publicEntry;
  });
  const payloadBytes = Buffer.from(JSON.stringify({
    schemaVersion: catalog.schemaVersion,
    sequence,
    issuedAtEpochSeconds,
    expiresAtEpochSeconds: issuedAtEpochSeconds + validityDays * 24 * 60 * 60,
    entries: catalogEntries,
    ...(catalog.schemaVersion === 2 ? { profiles: catalog.profiles } : {}),
  }));
  validateRegistryPayload(payloadBytes, {
    previousSequence,
    bundledProfiles,
    nowMillis,
  });
  return payloadBytes;
}

function decodeBase64(value, field) {
  if (typeof value !== 'string' || value.length === 0 ||
    !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) {
    throw new RegistryPayloadError(`${field} must be canonical base64`);
  }
  const decoded = Buffer.from(value, 'base64');
  if (decoded.toString('base64') !== value) fail(`${field} must be canonical base64`);
  return decoded;
}

export function validateRegistryPayload(payloadBytes, {
  previousSequence = 0,
  bundledProfiles = [],
  nowMillis = Date.now(),
} = {}) {
  if (!(payloadBytes instanceof Uint8Array)) fail('Payload must be bytes');
  if (payloadBytes.byteLength === 0 || payloadBytes.byteLength > MAX_ENVELOPE_BYTES) {
    fail('Payload size must be between 1 byte and 512 KiB');
  }
  let payloadText;
  try {
    payloadText = new TextDecoder('utf-8', { fatal: true }).decode(payloadBytes);
  } catch (error) {
    fail(`Payload must be valid UTF-8: ${error.message}`);
  }
  checkNoDuplicateObjectKeys(payloadText);

  let payload;
  try {
    payload = JSON.parse(payloadText);
  } catch (error) {
    fail(`Payload is not valid JSON: ${error.message}`);
  }
  if (!isRecord(payload)) fail('Payload root must be an object');
  const schemaVersion = requireInteger(payload, 'schemaVersion', 'Payload');
  if (schemaVersion !== 1 && schemaVersion !== 2) fail('schemaVersion must equal 1 or 2');
  const allowedPayloadKeys = schemaVersion === 1 ? allowedPayloadKeysV1 : allowedPayloadKeysV2;
  hasOnlyKeys(payload, allowedPayloadKeys, 'Payload');
  for (const required of allowedPayloadKeys) {
    if (!Object.hasOwn(payload, required)) fail(`Payload is missing required field: ${required}`);
  }
  const sequence = requireInteger(payload, 'sequence', 'Payload');
  if (sequence <= 0 || sequence <= previousSequence) {
    fail(`sequence must be positive and greater than ${previousSequence}`);
  }
  const issuedAt = requireInteger(payload, 'issuedAtEpochSeconds', 'Payload');
  const expiresAt = requireInteger(payload, 'expiresAtEpochSeconds', 'Payload');
  const nowSeconds = Math.floor(nowMillis / 1000);
  if (issuedAt <= 0 || expiresAt <= issuedAt) fail('Registry validity times are invalid');
  if (issuedAt > nowSeconds + 300) fail('issuedAtEpochSeconds is too far in the future');
  if (nowSeconds >= expiresAt) fail('Registry is already expired');
  if (!Array.isArray(payload.entries) || payload.entries.length > MAX_ENTRIES) {
    fail('entries must be an array of at most 10,000 records');
  }

  const bundledProfileIds = normalizeBundledProfiles(bundledProfiles);
  const remoteProfiles = schemaVersion === 2
    ? normalizeRemoteProfiles(payload.profiles)
    : new Map();
  const seenVersions = new Set();
  for (const [index, entry] of payload.entries.entries()) {
    const location = `entries[${index}]`;
    if (!isRecord(entry)) fail(`${location} must be an object`);
    hasOnlyKeys(entry, allowedEntryKeys, location);
    for (const required of ['packageName', 'versionName', 'status', 'sourceUrl']) {
      if (!Object.hasOwn(entry, required)) fail(`${location} is missing ${required}`);
    }
    if (typeof entry.packageName !== 'string' || !allowedPackages.has(entry.packageName)) {
      fail(`${location}.packageName is not allowlisted`);
    }
    if (typeof entry.versionName !== 'string' || !versionPattern.test(entry.versionName)) {
      fail(`${location}.versionName is invalid`);
    }
    if (typeof entry.status !== 'string' || !allowedStatuses.has(entry.status)) {
      fail(`${location}.status is invalid`);
    }
    const exactVersion = `${entry.packageName}\0${entry.versionName}`;
    if (seenVersions.has(exactVersion)) fail(`${location} duplicates a package/version entry`);
    seenVersions.add(exactVersion);

    if (typeof entry.sourceUrl !== 'string' || entry.sourceUrl.length > 512) {
      fail(`${location}.sourceUrl is invalid`);
    }
    let sourceUrl;
    try {
      sourceUrl = new URL(entry.sourceUrl);
    } catch {
      fail(`${location}.sourceUrl is not a valid URL`);
    }
    if (sourceUrl.protocol !== 'https:' || !sourceUrl.hostname ||
      sourceUrl.username || sourceUrl.password || sourceUrl.hash) {
      fail(`${location}.sourceUrl must be a public HTTPS URL without credentials or fragment`);
    }

    const hasProfileId = Object.hasOwn(entry, 'profileId');
    if (hasProfileId && (typeof entry.profileId !== 'string' || !profilePattern.test(entry.profileId))) {
      fail(`${location}.profileId is invalid`);
    }
    if (entry.status === 'catalogued' && hasProfileId) {
      fail(`${location}: catalogued entries cannot name a profile`);
    }
    const hasValidation = Object.hasOwn(entry, 'validation');
    if (schemaVersion === 2 && entry.status === 'supported') {
      validateVersionEvidence(entry.validation, `${location}.validation`);
    } else if (hasValidation) {
      fail(`${location}.validation is only allowed for supported schema v2 entries`);
    }
    if (entry.status === 'supported') {
      if (!hasProfileId) fail(`${location}: supported entries require a profile ID`);
      if (schemaVersion === 1) {
        if (!bundledProfileIds.has(`${entry.packageName}\0${entry.profileId}`)) {
          fail(`${location}: profile ID is not bundled for this package`);
        }
      } else {
        const profile = remoteProfiles.get(entry.profileId);
        if (!profile || profile.packageName !== entry.packageName) {
          fail(`${location}: profile ID is missing or belongs to another package`);
        }
      }
    }
    if (schemaVersion === 2 && hasProfileId) {
      const profile = remoteProfiles.get(entry.profileId);
      if (!profile || profile.packageName !== entry.packageName) {
        fail(`${location}: profile ID is missing or belongs to another package`);
      }
    }
  }
  return payload;
}

function validateVersionEvidence(validation, location) {
  if (!isRecord(validation)) fail(`${location} is required and must be an object`);
  hasOnlyKeys(validation, allowedValidationKeys, location);
  for (const key of allowedValidationKeys) {
    if (!Object.hasOwn(validation, key)) fail(`${location} is missing ${key}`);
  }
  if (typeof validation.reportId !== 'string' ||
    !/^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$/.test(validation.reportId)) {
    fail(`${location}.reportId is invalid`);
  }
  const integerFields = ['transitionCases', 'stationaryCases', 'deviceFamilies', 'stationaryRepeats'];
  for (const field of integerFields) {
    if (!Number.isSafeInteger(validation[field]) || validation[field] < 0) {
      fail(`${location}.${field} must be a non-negative integer`);
    }
  }
  if (validation.transitionCases < 200 || validation.stationaryCases < 100 ||
    validation.deviceFamilies < 3 || validation.stationaryRepeats !== 0) {
    fail(`${location} does not pass the FR-010–021 minimum case and repeat thresholds`);
  }
  for (const [field, minimum] of [['precisionPercent', 98], ['recallPercent', 90]]) {
    const value = validation[field];
    if (typeof value !== 'number' || !Number.isFinite(value) || value < minimum || value > 100) {
      fail(`${location}.${field} must be between ${minimum} and 100`);
    }
  }
  return validation;
}

function normalizeRemoteProfiles(profiles) {
  if (!Array.isArray(profiles) || profiles.length > 500) {
    fail('profiles must be an array of at most 500 definitions');
  }
  const byId = new Map();
  for (const [index, profile] of profiles.entries()) {
    const location = `profiles[${index}]`;
    if (!isRecord(profile)) fail(`${location} must be an object`);
    hasOnlyKeys(profile, allowedProfileKeys, location);
    for (const field of [
      'profileId', 'packageName', 'strategyId', 'feedMarkerViewIds',
      'transitionViewIds', 'identityStrategy',
    ]) {
      if (!Object.hasOwn(profile, field)) fail(`${location} is missing ${field}`);
    }
    if (typeof profile.profileId !== 'string' || !profilePattern.test(profile.profileId)) {
      fail(`${location}.profileId is invalid`);
    }
    if (byId.has(profile.profileId)) fail(`${location}.profileId is duplicated`);
    if (typeof profile.packageName !== 'string' || !allowedPackages.has(profile.packageName)) {
      fail(`${location}.packageName is not allowlisted`);
    }
    if (profile.strategyId !== 'accessibility_structure_v1') {
      fail(`${location}.strategyId is unknown`);
    }
    if (!allowedIdentityStrategies.has(profile.identityStrategy)) {
      fail(`${location}.identityStrategy is unknown`);
    }
    const idPattern = new RegExp(`^${escapeRegExp(profile.packageName)}:id/[a-z_][a-z0-9_]*$`);
    for (const field of ['feedMarkerViewIds', 'transitionViewIds']) {
      const ids = profile[field];
      if (!Array.isArray(ids) || ids.length < 1 || ids.length > 8 ||
        ids.some((id) => typeof id !== 'string' || !idPattern.test(id)) ||
        new Set(ids).size !== ids.length) {
        fail(`${location}.${field} must contain 1–8 unique exact resource IDs for its package`);
      }
    }
    const needsIdentityNode = profile.identityStrategy !== 'bounded_transition_fingerprint';
    if (needsIdentityNode) {
      if (typeof profile.identityNodeViewId !== 'string' || !idPattern.test(profile.identityNodeViewId)) {
        fail(`${location}.identityNodeViewId must be an exact resource ID for its package`);
      }
    } else if (Object.hasOwn(profile, 'identityNodeViewId')) {
      fail(`${location}.identityNodeViewId is not used by bounded_transition_fingerprint`);
    }
    byId.set(profile.profileId, profile);
  }
  return byId;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function signRegistryPayload(payloadBytes, privateKeyPem, options = {}) {
  const payload = validateRegistryPayload(payloadBytes, options);
  const privateKey = createPrivateKey(privateKeyPem);
  if (privateKey.asymmetricKeyType !== 'ec' ||
    privateKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
    fail('Signing key must be an ECDSA P-256 private key');
  }
  const signer = createSign('SHA256');
  signer.update(payloadBytes);
  signer.end();
  const envelope = {
    payload: Buffer.from(payloadBytes).toString('base64'),
    signature: signer.sign(privateKey).toString('base64'),
  };
  if (Buffer.byteLength(JSON.stringify(envelope), 'utf8') > MAX_ENVELOPE_BYTES) {
    fail('Signed envelope exceeds the Android 512 KiB limit');
  }
  return envelope;
}

export function verifySignedRegistry(envelopeText, publicKeyBase64, options = {}) {
  if (Buffer.byteLength(envelopeText, 'utf8') > MAX_ENVELOPE_BYTES) {
    fail('Envelope exceeds 512 KiB');
  }
  let envelope;
  try {
    checkNoDuplicateObjectKeys(envelopeText);
    envelope = JSON.parse(envelopeText);
  } catch (error) {
    fail(`Envelope is not valid JSON: ${error.message}`);
  }
  if (!isRecord(envelope) || Object.keys(envelope).length !== 2 ||
    !Object.hasOwn(envelope, 'payload') || !Object.hasOwn(envelope, 'signature')) {
    fail('Envelope must contain only payload and signature');
  }
  const payloadBytes = decodeBase64(envelope.payload, 'payload');
  if (payloadBytes.byteLength > MAX_ENVELOPE_BYTES) fail('Payload exceeds 512 KiB');
  const signatureBytes = decodeBase64(envelope.signature, 'signature');
  const publicKeyBytes = decodeBase64(publicKeyBase64.replace(/\s/g, ''), 'public key');
  const publicKey = createPublicKey({ key: publicKeyBytes, format: 'der', type: 'spki' });
  if (publicKey.asymmetricKeyType !== 'ec' ||
    publicKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
    fail('Verification key must be an ECDSA P-256 public key');
  }
  const verifier = createVerify('SHA256');
  verifier.update(payloadBytes);
  verifier.end();
  if (!verifier.verify(publicKey, signatureBytes)) fail('Signature verification failed');
  return validateRegistryPayload(payloadBytes, options);
}
