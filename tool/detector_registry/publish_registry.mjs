#!/usr/bin/env node

import { createHash, createPrivateKey, createPublicKey } from 'node:crypto';
import { readFileSync, readSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  buildRegistryPayload,
  signRegistryPayload,
  verifySignedRegistry,
} from './registry.mjs';

const usage = `Usage:
  node tool/detector_registry/publish_registry.mjs \\
    --catalog PATH --private-key PATH --output PATH \\
    --sequence N --previous-sequence N [--validity-days N] \\
    [--bundled-profiles PATH]

  node tool/detector_registry/publish_registry.mjs \\
    --catalog PATH --private-key-stdin --output PATH \\
    --sequence N --previous-sequence N [--validity-days N] \\
    [--bundled-profiles PATH]

The tool validates the exact payload bytes before signing and verifies the
resulting envelope before writing it. The stdin option accepts up to 16 KiB
of PEM key data and never writes or prints private key data.
`;

function parseArguments(arguments_) {
  const values = new Map();
  const allowed = new Set([
    'catalog', 'private-key', 'private-key-stdin', 'output', 'sequence', 'previous-sequence',
    'validity-days', 'bundled-profiles',
  ]);
  for (let index = 0; index < arguments_.length; index += 1) {
    const name = arguments_[index];
    if (name === '--help' || name === '-h') return { help: true, values };
    if (!name.startsWith('--') || !allowed.has(name.slice(2))) {
      throw new Error(`Unknown option: ${name}`);
    }
    const key = name.slice(2);
    if (values.has(key)) throw new Error(`Option --${key} was supplied more than once`);
    if (key === 'private-key-stdin') {
      values.set(key, true);
      continue;
    }
    const value = arguments_[index + 1];
    if (value === undefined || value.startsWith('--')) throw new Error(`Option --${key} needs a value`);
    values.set(key, value);
    index += 1;
  }
  return { help: false, values };
}

function privateKeyFromStdin(maxBytes = 16 * 1024) {
  const chunks = [];
  const buffer = Buffer.alloc(1024);
  let totalBytes = 0;
  while (true) {
    const bytesRead = readSync(0, buffer, 0, buffer.length, null);
    if (bytesRead === 0) break;
    totalBytes += bytesRead;
    if (totalBytes > maxBytes) throw new Error('Private-key stdin exceeds 16 KiB');
    chunks.push(Buffer.from(buffer.subarray(0, bytesRead)));
  }
  const pem = Buffer.concat(chunks).toString('utf8');
  if (!pem.trim()) throw new Error('Private-key stdin is empty');
  return pem;
}

function integerOption(values, name, { minimum = 0 } = {}) {
  const raw = values.get(name);
  if (raw === undefined || !/^(0|[1-9][0-9]*)$/.test(raw)) {
    throw new Error(`--${name} must be a base-10 integer`);
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < minimum) {
    throw new Error(`--${name} must be a safe integer of at least ${minimum}`);
  }
  return value;
}

function requiredPath(values, name) {
  const value = values.get(name);
  if (value === undefined || value.trim() === '') throw new Error(`Missing required --${name}`);
  return resolve(value);
}

function main() {
  const { help, values } = parseArguments(process.argv.slice(2));
  if (help) {
    process.stdout.write(usage);
    return;
  }
  for (const name of ['catalog', 'output']) {
    if (!values.has(name)) throw new Error(`Missing required --${name}`);
  }
  const hasPrivateKeyPath = values.has('private-key');
  const hasPrivateKeyStdin = values.has('private-key-stdin');
  if (hasPrivateKeyPath === hasPrivateKeyStdin) {
    throw new Error('Provide exactly one of --private-key PATH or --private-key-stdin');
  }
  for (const name of ['sequence', 'previous-sequence']) {
    if (!values.has(name)) throw new Error(`Missing required --${name}`);
  }

  const catalogPath = requiredPath(values, 'catalog');
  const privateKeyPath = hasPrivateKeyPath ? requiredPath(values, 'private-key') : null;
  const outputPath = requiredPath(values, 'output');
  const defaultProfilesPath = resolve(dirname(fileURLToPath(import.meta.url)), 'bundled-profiles.json');
  const profilesPath = values.has('bundled-profiles')
    ? requiredPath(values, 'bundled-profiles')
    : defaultProfilesPath;
  const inputPaths = new Set([catalogPath, ...(privateKeyPath ? [privateKeyPath] : []), profilesPath]);
  if (inputPaths.has(outputPath)) throw new Error('Output path must not overwrite an input file');

  const bundledProfiles = JSON.parse(readFileSync(profilesPath, 'utf8'));
  if (!Array.isArray(bundledProfiles)) throw new Error('Bundled profile file must contain a JSON array');
  const validityDays = values.has('validity-days')
    ? integerOption(values, 'validity-days', { minimum: 1 })
    : 30;
  const sequence = integerOption(values, 'sequence', { minimum: 1 });
  const previousSequence = integerOption(values, 'previous-sequence');
  const nowMillis = Date.now();
  const payloadBytes = buildRegistryPayload(readFileSync(catalogPath), {
    sequence,
    previousSequence,
    nowMillis,
    validityDays,
    bundledProfiles,
  });
  const privateKeyPem = hasPrivateKeyStdin
    ? privateKeyFromStdin()
    : readFileSync(privateKeyPath, 'utf8');
  const envelope = signRegistryPayload(payloadBytes, privateKeyPem, {
    previousSequence,
    bundledProfiles,
    nowMillis,
  });
  const privateKey = createPrivateKey(privateKeyPem);
  const publicKeyBase64 = createPublicKey(privateKey)
    .export({ type: 'spki', format: 'der' })
    .toString('base64');
  const envelopeText = JSON.stringify(envelope);
  const verified = verifySignedRegistry(envelopeText, publicKeyBase64, {
    previousSequence,
    bundledProfiles,
    nowMillis,
  });
  writeFileSync(outputPath, envelopeText, { encoding: 'utf8', flag: 'w' });
  const digest = createHash('sha256').update(payloadBytes).digest('hex');
  process.stdout.write(
    `Signed registry schema v${verified.schemaVersion}; sequence ${verified.sequence}; ` +
    `${verified.entries.length} entries; ${verified.profiles?.length ?? 0} profiles; ` +
    `expires ${new Date(verified.expiresAtEpochSeconds * 1000).toISOString()}; payload SHA-256 ${digest}\n`,
  );
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n${usage}`);
  process.exitCode = 1;
}
