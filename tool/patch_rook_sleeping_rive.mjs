// Build a dedicated Sleeping Rive review asset from the verified shared
// binary. The default pose uses the selected transparent Sleeping render; a
// slightly flatter closed-eye line appears during the brief blink.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path));
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
const source = read('assets/rook/rook.riv');
const expectedSource = '6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a';
if (sha(source) !== expectedSource) {
  throw new Error('Shared Rive binary changed; inspect before rebuilding Sleeping');
}

function varuint(number) {
  const out = [];
  do {
    let byte = number & 0x7f;
    number >>>= 7;
    if (number) byte |= 0x80;
    out.push(byte);
  } while (number);
  return Buffer.from(out);
}

function replaceUnique(file, before, after) {
  const at = file.indexOf(before);
  if (at < 0 || file.indexOf(before, at + 1) >= 0) {
    throw new Error('Expected exactly one matching Rive record');
  }
  return Buffer.concat([file.subarray(0, at), after, file.subarray(at + before.length)]);
}

function replaceImage(file, beforePath, afterPath) {
  const before = read(beforePath);
  const after = read(afterPath);
  return replaceUnique(
    file,
    Buffer.concat([varuint(before.length), before]),
    Buffer.concat([varuint(after.length), after]),
  );
}

const keyframe = (frame, value) => Buffer.concat([
  Buffer.from([0x1e]),
  ...(value === 1 ? [Buffer.from([0x46, 0, 0, 0x80, 0x3f])] : []),
  ...(frame ? [Buffer.from([0x43]), varuint(frame)] : []),
  Buffer.from([0x44, 0x01, 0x00]),
]);
const opacityTrack = (object, frames) => Buffer.concat([
  Buffer.from([0x19, 0x33, object, 0x00, 0x1a, 0x35, 0x12, 0x00]),
  ...frames.map(([frame, value]) => keyframe(frame, value)),
]);
const name = Buffer.from('Sleeping Blink');
const animation = Buffer.concat([
  Buffer.from([0x1f, 0x39]), varuint(240),
  Buffer.from([0x3b, 0x01, 0x37]), varuint(name.length), name, Buffer.from([0]),
  opacityTrack(0x26, [[0, 0]]),
  opacityTrack(0x28, [[0, 0]]),
  opacityTrack(0x2a, [[0, 0], [112, 0], [116, 1], [128, 1], [134, 0], [240, 0]]), // sleeping eye overlay
  opacityTrack(0x2c, [[0, 1]]), // Sleeping art beneath the eye overlay
  opacityTrack(0x2e, [[0, 0]]),
  opacityTrack(0x30, [[0, 0]]),
  opacityTrack(0x02, [[0, 0]]),
  opacityTrack(0x0b, [[0, 0]]),
  opacityTrack(0x14, [[0, 0]]),
  opacityTrack(0x1d, [[0, 0]]),
]);

let file = source;
const startName = file.indexOf('Ready Blink');
const endName = file.indexOf('Strained Blink');
if (startName < 8 || endName < startName) throw new Error('Animation boundaries missing');
const start = startName - 8;
const end = endName - 8;
if (!file.subarray(start, startName).equals(Buffer.from([0x1f, 0x39, 0xf0, 0x01, 0x3b, 0x01, 0x37, 0x0b])) ||
    !file.subarray(end, endName).equals(Buffer.from([0x1f, 0x39, 0xe8, 0x02, 0x3b, 0x01, 0x37, 0x0e]))) {
  throw new Error('Unexpected animation record layout');
}
file = Buffer.concat([file.subarray(0, start), animation, file.subarray(end)]);
file = replaceImage(file,
  'assets/rook/rook-injured-transparent.png',
  'assets/rook/rook-sleeping-transparent.png');
file = replaceImage(file,
  'assets/rook/rook-injured-blink-overlay.png',
  'assets/rook/rook-sleeping-eye-blink-overlay.png');

const output = resolve(root, 'assets/rook/rook-sleeping.riv');
writeFileSync(output, file);
console.log(`Wrote ${output} (${file.length} bytes, sha256 ${sha(file)})`);
