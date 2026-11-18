import test from 'node:test';
import assert from 'node:assert/strict';

import {
  createDiscoveryReport,
  discoverVersions,
  extractVersionCandidates,
  versionSources,
} from './discover_versions.mjs';

const youtube = versionSources.find(({ packageName }) =>
  packageName === 'com.google.android.youtube');
const instagram = versionSources.find(({ packageName }) =>
  packageName === 'com.instagram.android');

test('extracts only exact package-scoped numeric Android versions', () => {
  const html = `
    <a href="${youtube.downloadPath}21.45.82">stable</a>
    <a href="${youtube.downloadPath}21.45.82">duplicate</a>
    <a href="${youtube.downloadPath}21.45.82-SECONDARY">variant</a>
    <a href="${youtube.downloadPath}21.44.534?from=versions">query</a>
    <a href="https://evil.example${youtube.downloadPath}99.0.0">external</a>
    <a href="/other-package/download/99.0.0">other package</a>
    <a href="${instagram.downloadPath}455.0.0.51.72">other target</a>
  `;

  assert.deepEqual(extractVersionCandidates(html, youtube), [
    {
      packageName: 'com.google.android.youtube',
      versionName: '21.45.82',
      sourceIndexUrl: youtube.indexUrl,
      sourceUrl: `https://apkpure.net${youtube.downloadPath}21.45.82`,
      reviewRequired: true,
    },
  ]);
});

test('discovery reports new candidates without changing their support status', () => {
  const report = createDiscoveryReport({
    fetchedAt: '2026-11-13T00:00:00.000Z',
    catalog: [
      { packageName: 'com.google.android.youtube', versionName: '21.45.82' },
    ],
    observations: [
      { target: youtube, versions: ['21.45.82', '21.46.100'] },
      { target: instagram, versions: ['455.0.0.51.72', '456.0.0.51.80'] },
    ],
  });

  assert.deepEqual(report.newCandidates.map(({ packageName, versionName }) => [
    packageName,
    versionName,
  ]), [
    ['com.google.android.youtube', '21.46.100'],
    ['com.instagram.android', '455.0.0.51.72'],
    ['com.instagram.android', '456.0.0.51.80'],
  ]);
  assert.ok(report.newCandidates.every((candidate) => candidate.reviewRequired));
  assert.equal(report.schemaVersion, 1);
});

test('fetches every configured index over the pinned APKPure origin', async () => {
  const requested = [];
  const fetchImpl = async (url, options) => {
    requested.push({ url, options });
    const target = versionSources.find((source) => source.indexUrl === url);
    const response = new Response(
      `<a href="${target.downloadPath}${target.packageName === 'com.google.android.youtube' ? '21.45.82' : '455.0.0.51.72'}">v</a>`,
      {
        status: 200,
        headers: { 'content-type': 'text/html; charset=utf-8' },
      },
    );
    Object.defineProperty(response, 'url', { value: url });
    return response;
  };

  const report = await discoverVersions({
    catalog: [],
    fetchImpl,
    now: () => new Date('2026-11-13T00:00:00.000Z'),
  });

  assert.equal(report.sources.length, versionSources.length);
  assert.equal(requested.length, versionSources.length);
  assert.ok(requested.every(({ options }) => options.redirect === 'error'));
  assert.ok(report.newCandidates.every(({ reviewRequired }) => reviewRequired));
});

test('rejects redirects, error responses, and unexpected document types', async () => {
  for (const response of [
    new Response('', { status: 302, headers: { location: 'https://evil.example' } }),
    new Response('denied', { status: 403, headers: { 'content-type': 'text/html' } }),
    new Response('{}', { status: 200, headers: { 'content-type': 'application/json' } }),
  ]) {
    Object.defineProperty(response, 'url', { value: youtube.indexUrl });
    await assert.rejects(
      discoverVersions({
        catalog: [],
        fetchImpl: async () => response,
        now: () => new Date('2026-11-13T00:00:00.000Z'),
      }),
    );
  }
});

test('rejects injected non-version values before producing review links', () => {
  assert.throws(() => createDiscoveryReport({
    fetchedAt: '2026-11-13T00:00:00.000Z',
    catalog: [],
    observations: [{ target: youtube, versions: ['../../other-host'] }],
  }), /invalid version name/);
});
