#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const APKPURE_ORIGIN = 'https://apkpure.net';
const MAX_INDEX_BYTES = 2 * 1024 * 1024;
const REQUEST_TIMEOUT_MILLIS = 15_000;

export const versionSources = Object.freeze([
  Object.freeze({
    packageName: 'com.google.android.youtube',
    indexUrl: `${APKPURE_ORIGIN}/youtube-app/com.google.android.youtube/versions`,
    downloadPath: '/youtube-app/com.google.android.youtube/download/',
  }),
  Object.freeze({
    packageName: 'com.instagram.android',
    indexUrl: `${APKPURE_ORIGIN}/instagram-app/com.instagram.android/versions`,
    downloadPath: '/instagram-app/com.instagram.android/download/',
  }),
]);

function decodeHtmlAttribute(value) {
  return value.replace(/&amp;/gi, '&').replace(/&#x2f;/gi, '/').replace(/&#47;/g, '/');
}

function hrefsFrom(html) {
  return [...html.matchAll(/\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'`<>]+))/gi)]
    .map((match) => decodeHtmlAttribute(match[1] ?? match[2] ?? match[3] ?? ''));
}

function isValidTarget(target) {
  if (!target || typeof target !== 'object') return false;
  let indexUrl;
  try {
    indexUrl = new URL(target.indexUrl);
  } catch {
    return false;
  }
  return indexUrl.protocol === 'https:' && indexUrl.origin === APKPURE_ORIGIN &&
    versionSources.some((configured) =>
      configured.packageName === target.packageName &&
      configured.indexUrl === target.indexUrl &&
      configured.downloadPath === target.downloadPath);
}

export function extractVersionCandidates(html, target) {
  if (typeof html !== 'string') throw new TypeError('Version index HTML must be a string');
  if (!isValidTarget(target)) throw new TypeError('Version source target is invalid');

  const indexUrl = new URL(target.indexUrl);
  const candidates = [];
  const seen = new Set();
  for (const href of hrefsFrom(html)) {
    let link;
    try {
      link = new URL(href, indexUrl);
    } catch {
      continue;
    }
    if (link.protocol !== 'https:' || link.origin !== APKPURE_ORIGIN ||
        link.search || link.hash || !link.pathname.startsWith(target.downloadPath)) {
      continue;
    }

    const versionName = link.pathname.slice(target.downloadPath.length);
    // Variant suffixes are not proven PackageInfo.versionName values.
    if (!/^\d+(?:\.\d+){1,5}$/.test(versionName) || seen.has(versionName)) continue;
    seen.add(versionName);
    candidates.push({
      packageName: target.packageName,
      versionName,
      sourceIndexUrl: target.indexUrl,
      sourceUrl: `${APKPURE_ORIGIN}${target.downloadPath}${versionName}`,
      reviewRequired: true,
    });
  }
  return candidates;
}

export function createDiscoveryReport({ catalog, observations, fetchedAt }) {
  if (!Array.isArray(catalog)) throw new TypeError('Registry catalog must contain an entries array');
  if (!Array.isArray(observations)) throw new TypeError('Discovery observations must be an array');
  if (typeof fetchedAt !== 'string' || Number.isNaN(Date.parse(fetchedAt))) {
    throw new TypeError('Discovery timestamp must be a valid ISO date string');
  }

  const existing = new Set(catalog.map((entry) => `${entry.packageName}\u0000${entry.versionName}`));
  const sources = [];
  const newCandidates = [];
  for (const observation of observations) {
    if (!isValidTarget(observation?.target) || !Array.isArray(observation.versions)) {
      throw new TypeError('Discovery observation is invalid');
    }
    const uniqueVersions = [...new Set(observation.versions)];
    if (!uniqueVersions.every((versionName) =>
      typeof versionName === 'string' && /^\d+(?:\.\d+){1,5}$/.test(versionName))) {
      throw new TypeError('Discovery observations contain an invalid version name');
    }
    sources.push({
      packageName: observation.target.packageName,
      indexUrl: observation.target.indexUrl,
      observedVersionNames: uniqueVersions,
      observedCount: uniqueVersions.length,
    });
    for (const versionName of uniqueVersions) {
      const key = `${observation.target.packageName}\u0000${versionName}`;
      if (existing.has(key)) continue;
      newCandidates.push({
        packageName: observation.target.packageName,
        versionName,
        sourceIndexUrl: observation.target.indexUrl,
        sourceUrl: `${APKPURE_ORIGIN}${observation.target.downloadPath}${versionName}`,
        status: 'review_required',
        reviewRequired: true,
      });
    }
  }
  return { schemaVersion: 1, fetchedAt, sources, newCandidates };
}

async function readLimitedText(response, maxBytes) {
  if (!response.body) throw new Error('Version source response has no body');
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > maxBytes) {
      await reader.cancel();
      throw new Error('Version source response exceeds the 2 MiB limit');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
}

export async function discoverVersions({
  catalog,
  fetchImpl = globalThis.fetch,
  now = () => new Date(),
  targets = versionSources,
}) {
  if (typeof fetchImpl !== 'function') throw new TypeError('A fetch implementation is required');
  if (!Array.isArray(catalog)) throw new TypeError('Registry catalog must contain an entries array');
  if (!Array.isArray(targets) || targets.length === 0 || !targets.every(isValidTarget)) {
    throw new TypeError('At least one valid HTTPS version source is required');
  }

  const observations = [];
  for (const target of targets) {
    const response = await fetchImpl(target.indexUrl, {
      headers: { accept: 'text/html' },
      redirect: 'error',
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MILLIS),
    });
    if (response.status !== 200) {
      throw new Error(`Version source returned HTTP ${response.status}: ${target.packageName}`);
    }
    if (response.url !== target.indexUrl) {
      throw new Error(`Version source changed its URL: ${target.packageName}`);
    }
    if (!response.headers.get('content-type')?.toLowerCase().includes('text/html')) {
      throw new Error(`Version source did not return HTML: ${target.packageName}`);
    }
    const html = await readLimitedText(response, MAX_INDEX_BYTES);
    const candidates = extractVersionCandidates(html, target);
    if (candidates.length === 0) {
      throw new Error(`Version source contained no exact numeric version links: ${target.packageName}`);
    }
    observations.push({ target, versions: candidates.map(({ versionName }) => versionName) });
  }

  return createDiscoveryReport({
    catalog,
    observations,
    fetchedAt: now().toISOString(),
  });
}

function parseArguments(args) {
  const values = new Map();
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--help' || argument === '-h') return { help: true, values };
    if (!['--catalog', '--output'].includes(argument)) throw new Error(`Unknown option: ${argument}`);
    const value = args[index + 1];
    if (!value || value.startsWith('--')) throw new Error(`${argument} needs a path`);
    if (values.has(argument)) throw new Error(`${argument} was provided more than once`);
    values.set(argument, resolve(value));
    index += 1;
  }
  return { help: false, values };
}

async function main() {
  const { help, values } = parseArguments(process.argv.slice(2));
  if (help) {
    process.stdout.write('Usage: node tool/detector_registry/discover_versions.mjs [--catalog PATH] [--output PATH]\n');
    return;
  }
  const toolDirectory = dirname(fileURLToPath(import.meta.url));
  const catalogPath = values.get('--catalog') ?? resolve(toolDirectory, 'registry-catalog.json');
  const outputPath = values.get('--output') ?? resolve(toolDirectory, 'discovery-candidates.json');
  if (catalogPath === outputPath) throw new Error('Output cannot overwrite the signed registry catalog');

  const catalog = JSON.parse(readFileSync(catalogPath, 'utf8'));
  const report = await discoverVersions({ catalog: catalog.entries });
  writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
  process.stdout.write(
    `Observed ${report.sources.reduce((sum, source) => sum + source.observedCount, 0)} version links; ` +
    `${report.newCandidates.length} new candidates require review.\n${outputPath}\n`,
  );
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    process.stderr.write(`Version discovery failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
