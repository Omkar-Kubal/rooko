import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

import {
  RegistryPayloadError,
  buildRegistryPayload,
  signRegistryPayload,
  validateRegistryPayload,
  verifySignedRegistry,
} from './registry.mjs';

const now = Math.floor(Date.now() / 1000);
const youtube = 'com.google.android.youtube';
const instagram = 'com.instagram.android';

function payloadWith(entries, overrides = {}) {
  return Buffer.from(JSON.stringify({
    schemaVersion: 1,
    sequence: 8,
    issuedAtEpochSeconds: now - 1,
    expiresAtEpochSeconds: now + 60,
    entries,
    ...overrides,
  }));
}

function catalogued(packageName = youtube, versionName = '21.45.82') {
  return {
    packageName,
    versionName,
    status: 'catalogued',
    sourceUrl: 'https://www.apkmirror.com/apk/google-inc/youtube/',
  };
}

function youtubeProfile(overrides = {}) {
  return {
    profileId: 'youtube.shorts.structure.v1',
    packageName: youtube,
    strategyId: 'accessibility_structure_v1',
    feedMarkerViewIds: [`${youtube}:id/shorts_feed`],
    transitionViewIds: [`${youtube}:id/shorts_pager`],
    identityStrategy: 'structural_node_pair',
    identityNodeViewId: `${youtube}:id/shorts_item`,
    ...overrides,
  };
}

function validationEvidence(reportId = 'youtube-21-45-82-validation') {
  return {
    reportId,
    transitionCases: 200,
    stationaryCases: 100,
    deviceFamilies: 3,
    precisionPercent: 98,
    recallPercent: 90,
    stationaryRepeats: 0,
  };
}

function v2PayloadWith(entries, profiles = [youtubeProfile()], overrides = {}) {
  return Buffer.from(JSON.stringify({
    schemaVersion: 2,
    sequence: 8,
    issuedAtEpochSeconds: now - 1,
    expiresAtEpochSeconds: now + 60,
    entries: entries.map((entry) => entry.status === 'supported' && !Object.hasOwn(entry, 'validation')
      ? { ...entry, validation: validationEvidence(`validation-${entry.versionName}`) }
      : entry),
    profiles,
    ...overrides,
  }));
}

function expectInvalid(payloadBytes, options = {}) {
  assert.throws(
    () => validateRegistryPayload(payloadBytes, options),
    RegistryPayloadError,
  );
}

test('accepts an exact sourced catalog entry without enabling a profile', () => {
  const parsed = validateRegistryPayload(payloadWith([catalogued()]));
  assert.equal(parsed.entries[0].versionName, '21.45.82');
  assert.equal(parsed.entries[0].status, 'catalogued');
  assert.equal(parsed.entries[0].profileId, undefined);
});

test('builds a fresh, validated payload from a curated catalog and monotonic sequence', () => {
  const catalogBytes = Buffer.from(JSON.stringify({ schemaVersion: 1, entries: [catalogued()] }));
  const payloadBytes = buildRegistryPayload(catalogBytes, {
    sequence: 9,
    previousSequence: 8,
    nowMillis: now * 1000,
  });

  const payload = JSON.parse(payloadBytes.toString('utf8'));
  assert.equal(payload.sequence, 9);
  assert.equal(payload.issuedAtEpochSeconds, now);
  assert.equal(payload.expiresAtEpochSeconds, now + 30 * 24 * 60 * 60);
  assert.deepEqual(payload.entries, [catalogued()]);
  assert.equal(validateRegistryPayload(payloadBytes, {
    previousSequence: 8,
    nowMillis: now * 1000,
  }).sequence, 9);
});

test('refuses to build a payload with a reused sequence or malformed curated catalog', () => {
  const validCatalog = Buffer.from(JSON.stringify({ schemaVersion: 1, entries: [catalogued()] }));
  assert.throws(() => buildRegistryPayload(validCatalog, {
    sequence: 8,
    previousSequence: 8,
    nowMillis: now * 1000,
  }), RegistryPayloadError);
  assert.throws(() => buildRegistryPayload(Buffer.from('{"schemaVersion":1,"entries":[]}'), {
    sequence: 1,
    previousSequence: 0,
    nowMillis: now * 1000,
    validityDays: 0,
  }), RegistryPayloadError);
  assert.throws(() => buildRegistryPayload(Buffer.from('{"schemaVersion":1,"schemaVersion":1,"entries":[]}'), {
    sequence: 1,
    previousSequence: 0,
    nowMillis: now * 1000,
  }), RegistryPayloadError);
});

test('the checked-in catalog contains only sourced catalogued versions and no remote profiles', () => {
  const catalogBytes = readFileSync('tool/detector_registry/registry-catalog.json');
  const payloadBytes = buildRegistryPayload(catalogBytes, {
    sequence: 1,
    previousSequence: 0,
    nowMillis: Date.now(),
  });
  const payload = JSON.parse(payloadBytes.toString('utf8'));

  assert.equal(payload.entries.length, 20);
  assert.equal(payload.schemaVersion, 2);
  assert.deepEqual(payload.profiles, []);
  assert.ok(payload.entries.some((entry) =>
    entry.packageName === 'com.instagram.android' &&
    entry.versionName === '455.0.0.51.72' &&
    entry.status === 'catalogued' &&
    entry.sourceUrl === 'https://www.apkmirror.com/apk/instagram/instagram-instagram/instagram-455-0-0-51-72-release/'));
  assert.ok(payload.entries.some((entry) =>
    entry.packageName === 'com.google.android.youtube' &&
    entry.versionName === '21.44.528' &&
    entry.sourceUrl === 'https://apkpure.net/youtube-app/com.google.android.youtube/download/21.44.528'));
  assert.ok(payload.entries.some((entry) =>
    entry.packageName === 'com.google.android.youtube' &&
    entry.versionName === '21.42.243' &&
    entry.sourceUrl === 'https://apkpure.net/youtube-app/com.google.android.youtube/download/21.42.243'));
  assert.ok(payload.entries.every((entry) => entry.status === 'catalogued' && !Object.hasOwn(entry, 'profileId')));
  assert.ok(payload.entries.every((entry) => new URL(entry.sourceUrl).protocol === 'https:'));
  assert.ok(payload.entries.every((entry) => !/-(?:BETA|SECONDARY)$/.test(entry.versionName)));
  assert.ok(payload.entries.every((entry) => !/\/download$/.test(new URL(entry.sourceUrl).pathname)));
});

test('rejects duplicate package and version entries', () => {
  expectInvalid(payloadWith([catalogued(), catalogued()]));
});

test('rejects unknown packages, malformed versions, and extra fields', () => {
  expectInvalid(payloadWith([catalogued('com.example.app')]));
  expectInvalid(payloadWith([catalogued(youtube, '21/45/82')]));
  expectInvalid(payloadWith([{ ...catalogued(), injected: true }]));
});

test('requires a public HTTPS source URL', () => {
  expectInvalid(payloadWith([{ ...catalogued(), sourceUrl: 'http://example.com/release' }]));
  expectInvalid(payloadWith([{ ...catalogued(), sourceUrl: 'https://user:pass@example.com/release' }]));
  expectInvalid(payloadWith([{ ...catalogued(), sourceUrl: 'https://example.com/release#fragment' }]));
});

test('enforces status and bundled profile membership', () => {
  const supported = {
    packageName: instagram,
    versionName: '455.0.0.51.72',
    status: 'supported',
    profileId: 'instagram.reels.v1',
    sourceUrl: 'https://apkpure.net/instagram-app/com.instagram.android/versions',
  };
  expectInvalid(payloadWith([supported]));
  assert.equal(
    validateRegistryPayload(payloadWith([supported]), {
      bundledProfiles: [{ packageName: instagram, profileId: 'instagram.reels.v1' }],
    }).entries[0].profileId,
    'instagram.reels.v1',
  );
  expectInvalid(payloadWith([{ ...catalogued(), profileId: 'youtube.shorts.v1' }]), {
    bundledProfiles: [{ packageName: youtube, profileId: 'youtube.shorts.v1' }],
  });
});

test('accepts one bounded remote profile shared by individually mapped exact versions', () => {
  const entries = ['21.45.82', '21.46.83'].map((versionName) => ({
    ...catalogued(youtube, versionName),
    status: 'supported',
    profileId: 'youtube.shorts.structure.v1',
  }));
  const parsed = validateRegistryPayload(v2PayloadWith(entries));
  assert.equal(parsed.schemaVersion, 2);
  assert.equal(parsed.profiles.length, 1);
  assert.deepEqual(entries.map((entry) => entry.profileId), [
    parsed.profiles[0].profileId,
    parsed.profiles[0].profileId,
  ]);
});

test('rejects remote profiles with unsafe fields, unknown strategies, or malformed IDs', () => {
  const supported = {
    ...catalogued(),
    status: 'supported',
    profileId: 'youtube.shorts.structure.v1',
  };
  expectInvalid(v2PayloadWith([supported], [youtubeProfile({ javascript: 'return true' })]));
  expectInvalid(v2PayloadWith([supported], [youtubeProfile({ strategyId: 'remote_xpath' })]));
  expectInvalid(v2PayloadWith([supported], [youtubeProfile({ identityStrategy: 'read_text' })]));
  expectInvalid(v2PayloadWith([supported], [youtubeProfile({
    feedMarkerViewIds: ['com.instagram.android:id/reels_view'],
  })]));
  expectInvalid(v2PayloadWith([supported], [youtubeProfile({
    transitionViewIds: Array.from({ length: 9 }, (_, index) => `${youtube}:id/pager_${index}`),
  })]));
  expectInvalid(v2PayloadWith([supported], [youtubeProfile({
    identityNodeViewId: `${youtube}:id/../text`,
  })]));
});

test('rejects missing, duplicate, and package-mismatched remote profiles', () => {
  const supported = {
    ...catalogued(),
    status: 'supported',
    profileId: 'youtube.shorts.structure.v1',
  };
  expectInvalid(v2PayloadWith([supported], []));
  expectInvalid(v2PayloadWith([supported], [youtubeProfile(), youtubeProfile()]));
  expectInvalid(v2PayloadWith([{
    ...catalogued(instagram),
    status: 'supported',
    profileId: 'youtube.shorts.structure.v1',
  }]));
});

test('requires passing signed validation evidence for every supported v2 version', () => {
  const supported = {
    ...catalogued(),
    status: 'supported',
    profileId: 'youtube.shorts.structure.v1',
  };
  const failingResults = [
    validationEvidence('few-transitions'),
    validationEvidence('few-stationary'),
    validationEvidence('two-devices'),
    validationEvidence('low-precision'),
    validationEvidence('low-recall'),
    validationEvidence('repeat'),
  ];
  failingResults[0].transitionCases = 199;
  failingResults[1].stationaryCases = 99;
  failingResults[2].deviceFamilies = 2;
  failingResults[3].precisionPercent = 97.99;
  failingResults[4].recallPercent = 89.99;
  failingResults[5].stationaryRepeats = 1;
  for (const validation of failingResults) {
    expectInvalid(v2PayloadWith([{ ...supported, validation }]));
  }
  expectInvalid(v2PayloadWith([{ ...supported, validation: null }]));
});

test('publisher will not emit a supported version without passing evidence', () => {
  const catalogBytes = Buffer.from(JSON.stringify({
    schemaVersion: 2,
    profiles: [youtubeProfile()],
    entries: [{
      ...catalogued(),
      status: 'supported',
      profileId: 'youtube.shorts.structure.v1',
    }],
  }));
  assert.throws(() => buildRegistryPayload(catalogBytes, {
    sequence: 9,
    previousSequence: 8,
    nowMillis: now * 1000,
  }), RegistryPayloadError);
});

test('requires a new positive sequence and ordered, current validity times', () => {
  expectInvalid(payloadWith([catalogued()], { sequence: 8 }), { previousSequence: 8 });
  expectInvalid(payloadWith([catalogued()], { sequence: 0 }));
  expectInvalid(payloadWith([catalogued()], {
    issuedAtEpochSeconds: now + 601,
    expiresAtEpochSeconds: now + 1200,
  }));
  expectInvalid(payloadWith([catalogued()], {
    issuedAtEpochSeconds: now,
    expiresAtEpochSeconds: now,
  }));
});

test('rejects invalid UTF-8 JSON and payloads larger than the Android limit', () => {
  expectInvalid(Buffer.from([0xc3, 0x28]));
  expectInvalid(Buffer.alloc(512 * 1024 + 1));
});

test('rejects a valid payload whose base64 signed envelope exceeds the Android limit', () => {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const payloadBytes = Buffer.concat([payloadWith([]), Buffer.alloc(400 * 1024, 0x20)]);

  assert.throws(() => signRegistryPayload(
    payloadBytes,
    privateKey.export({ type: 'pkcs8', format: 'pem' }),
  ), RegistryPayloadError);
});

test('rejects repeated JSON keys before parsing signed data', () => {
  const duplicateKeyPayload = Buffer.from(
    `{"schemaVersion":1,"schemaVersion":1,"sequence":8,"issuedAtEpochSeconds":${now - 1},"expiresAtEpochSeconds":${now + 60},"entries":[]}`,
  );
  expectInvalid(duplicateKeyPayload);
});

test('signs the exact payload bytes and verifies the P-256 envelope', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const payloadBytes = payloadWith([catalogued()]);
  const publicKeyBase64 = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');
  const envelope = signRegistryPayload(payloadBytes, privateKey.export({ type: 'pkcs8', format: 'pem' }), {
    previousSequence: 7,
  });

  assert.equal(Buffer.from(envelope.payload, 'base64').toString('hex'), payloadBytes.toString('hex'));
  const verified = verifySignedRegistry(JSON.stringify(envelope), publicKeyBase64, { nowMillis: now * 1000 });
  assert.equal(verified.sequence, 8);
  assert.equal(verified.entries[0].versionName, '21.45.82');

  const tampered = { ...envelope, payload: Buffer.from(payloadWith([catalogued(youtube, '21.45.83')])).toString('base64') };
  assert.throws(() => verifySignedRegistry(JSON.stringify(tampered), publicKeyBase64, {
    nowMillis: now * 1000,
  }));
});

test('publisher CLI signs supported entries when their profile is bundled', () => {
  const directory = mkdtempSync(join(tmpdir(), 'rooko-registry-'));
  try {
    const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const privateKeyPath = join(directory, 'private.pem');
    const catalogPath = join(directory, 'catalog.json');
    const bundledProfilesPath = join(directory, 'profiles.json');
    const outputPath = join(directory, 'registry.json');
    writeFileSync(privateKeyPath, privateKey.export({ type: 'pkcs8', format: 'pem' }));
    writeFileSync(catalogPath, JSON.stringify({
      schemaVersion: 1,
      entries: [{
        ...catalogued(),
        status: 'supported',
        profileId: 'youtube.shorts.v1',
        validation: validationEvidence(),
      }],
    }));
    writeFileSync(bundledProfilesPath, JSON.stringify([{
      packageName: youtube,
      profileId: 'youtube.shorts.v1',
    }]));

    const result = spawnSync(process.execPath, [
      'tool/detector_registry/publish_registry.mjs',
      '--catalog', catalogPath,
      '--private-key', privateKeyPath,
      '--bundled-profiles', bundledProfilesPath,
      '--sequence', '9',
      '--previous-sequence', '8',
      '--output', outputPath,
    ], { encoding: 'utf8' });

    assert.equal(result.status, 0, result.stderr);
    const envelope = readFileSync(outputPath, 'utf8');
    const publicKeyBase64 = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');
    const verified = verifySignedRegistry(envelope, publicKeyBase64, {
      previousSequence: 8,
      bundledProfiles: JSON.parse(readFileSync(bundledProfilesPath, 'utf8')),
      nowMillis: now * 1000,
    });
    assert.equal(verified.sequence, 9);
    assert.equal(verified.entries[0].status, 'supported');
    assert.equal(verified.entries[0].profileId, 'youtube.shorts.v1');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('publisher CLI signs and verifies schema v2 remote profile data', () => {
  const directory = mkdtempSync(join(tmpdir(), 'rooko-remote-profiles-'));
  try {
    const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const privateKeyPath = join(directory, 'private.pem');
    const catalogPath = join(directory, 'catalog.json');
    const outputPath = join(directory, 'registry.json');
    writeFileSync(privateKeyPath, privateKey.export({ type: 'pkcs8', format: 'pem' }));
    writeFileSync(catalogPath, JSON.stringify({
      schemaVersion: 2,
      profiles: [youtubeProfile()],
      entries: [{
        ...catalogued(),
        status: 'supported',
        profileId: 'youtube.shorts.structure.v1',
        validation: validationEvidence(),
      }],
    }));

    const result = spawnSync(process.execPath, [
      'tool/detector_registry/publish_registry.mjs',
      '--catalog', catalogPath,
      '--private-key', privateKeyPath,
      '--sequence', '9',
      '--previous-sequence', '8',
      '--output', outputPath,
    ], { encoding: 'utf8' });

    assert.equal(result.status, 0, result.stderr);
    const publicKeyBase64 = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');
    const verified = verifySignedRegistry(readFileSync(outputPath, 'utf8'), publicKeyBase64, {
      previousSequence: 8,
      nowMillis: now * 1000,
    });
    assert.equal(verified.schemaVersion, 2);
    assert.equal(verified.entries[0].profileId, 'youtube.shorts.structure.v1');
    assert.equal(verified.profiles[0].strategyId, 'accessibility_structure_v1');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('publisher CLI accepts a protected signing key through stdin without a key file', () => {
  const directory = mkdtempSync(join(tmpdir(), 'rooko-registry-stdin-'));
  try {
    const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
    const catalogPath = join(directory, 'catalog.json');
    const outputPath = join(directory, 'registry.json');
    const privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' });
    writeFileSync(catalogPath, JSON.stringify({ schemaVersion: 1, entries: [catalogued()] }));

    const result = spawnSync(process.execPath, [
      'tool/detector_registry/publish_registry.mjs',
      '--catalog', catalogPath,
      '--private-key-stdin',
      '--sequence', '9',
      '--previous-sequence', '8',
      '--output', outputPath,
    ], { encoding: 'utf8', input: privateKeyPem });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.includes(privateKeyPem), false);
    const publicKeyBase64 = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');
    const verified = verifySignedRegistry(readFileSync(outputPath, 'utf8'), publicKeyBase64, {
      previousSequence: 8,
      nowMillis: now * 1000,
    });
    assert.equal(verified.sequence, 9);
    assert.equal(verified.entries[0].status, 'catalogued');
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('shared publisher fixture verifies as the Android envelope contract', () => {
  const envelopeFixturePath = 'tool/detector_registry/test-fixtures/registry-envelope.json';
  const publicKeyFixturePath = 'tool/detector_registry/test-fixtures/registry-public-key.b64';
  const androidFixturePath = 'android/app/src/test/resources/detector_registry';
  const envelopeBytes = readFileSync(envelopeFixturePath);
  const publicKeyBytes = readFileSync(publicKeyFixturePath);
  assert.deepEqual(readFileSync(`${androidFixturePath}/registry-envelope.json`), envelopeBytes);
  assert.deepEqual(readFileSync(`${androidFixturePath}/registry-public-key.b64`), publicKeyBytes);
  const envelope = envelopeBytes.toString('utf8');
  const publicKeyBase64 = publicKeyBytes.toString('utf8').trim();
  const verified = verifySignedRegistry(envelope, publicKeyBase64, {
    previousSequence: 6,
    nowMillis: 1_800_000_000_000,
  });

  assert.equal(verified.sequence, 7);
  assert.equal(verified.entries[0].versionName, '21.45.82');
  assert.equal(verified.entries[0].status, 'catalogued');
});

test('shared schema v2 profile fixture matches Android test resources', () => {
  const envelopeBytes = readFileSync('tool/detector_registry/test-fixtures/registry-envelope-v2.json');
  const publicKeyBytes = readFileSync('tool/detector_registry/test-fixtures/registry-public-key-v2.b64');
  const androidFixturePath = 'android/app/src/test/resources/detector_registry';
  assert.deepEqual(
    readFileSync(`${androidFixturePath}/registry-envelope-v2.json`),
    envelopeBytes,
  );
  assert.deepEqual(
    readFileSync(`${androidFixturePath}/registry-public-key-v2.b64`),
    publicKeyBytes,
  );

  const verified = verifySignedRegistry(
    envelopeBytes.toString('utf8'),
    publicKeyBytes.toString('utf8').trim(),
    { nowMillis: 1_800_000_000_000 },
  );
  assert.equal(verified.schemaVersion, 2);
  assert.equal(verified.entries[0].versionName, '21.45.82');
  assert.equal(verified.entries[0].validation.reportId, 'fixture-only');
  assert.equal(verified.profiles[0].strategyId, 'accessibility_structure_v1');
});
