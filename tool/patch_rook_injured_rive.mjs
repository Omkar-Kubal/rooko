// Rebuild the staged Injured Rive binary from the last verified Ready/Strained asset.
// The Rive CLI's local .riv export now requires an account; the editable target
// scene remains assets/rook/scene.rml. This patch changes only embedded PNGs and
// the existing Injured animation in the pre-exported shared binary.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path));
const base = read('archive/rook/ready-strained-before-injured/rook.riv');
const expectedBase = '25a9496ec0a15f582c692c3fc5856492fc677dfd1bcd37113df1c1f65873129f';
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
if (sha(base) !== expectedBase) throw new Error('Rive base changed; inspect before patching');

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

function replaceUnique(haystack, needle, replacement) {
  const at = haystack.indexOf(needle);
  if (at < 0 || haystack.indexOf(needle, at + 1) >= 0) {
    throw new Error('Expected exactly one matching Rive record');
  }
  return Buffer.concat([haystack.subarray(0, at), replacement, haystack.subarray(at + needle.length)]);
}

function replaceAsset(file, oldPath, newPath) {
  const oldPng = read(oldPath);
  const newPng = read(newPath);
  const oldRecord = Buffer.concat([varuint(oldPng.length), oldPng]);
  const newRecord = Buffer.concat([varuint(newPng.length), newPng]);
  return replaceUnique(file, oldRecord, newRecord);
}

// Rive file v7's existing LinearAnimation/KeyedObject/KeyedProperty records.
// Object ids are the compiled indices in this exact archived base. The art and
// overlay remain stationary; only the overlay's opacity changes with time.
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
const animationName = Buffer.from('Injured Blink');
const animation = Buffer.concat([
  Buffer.from([0x1f, 0x39]), varuint(320),
  Buffer.from([0x3b, 0x01, 0x37]), varuint(animationName.length), animationName, Buffer.from([0]),
  opacityTrack(0x26, [[0, 0]]), // Ready art
  opacityTrack(0x28, [[0, 0]]), // Strained art
  opacityTrack(0x2a, [[0, 0], [148, 0], [154, 1], [158, 1], [164, 0], [320, 0]]), // eyelids
  opacityTrack(0x2c, [[0, 1]]), // Injured art
  opacityTrack(0x2e, [[0, 0]]), // dormant Recovering art
  opacityTrack(0x30, [[0, 0]]), // dormant Victorious art
  opacityTrack(0x02, [[0, 0]]), // Ready left eyelid
  opacityTrack(0x0b, [[0, 0]]), // Ready right eyelid
  opacityTrack(0x14, [[0, 0]]), // Strained left eyelid
  opacityTrack(0x1d, [[0, 0]]), // Strained right eyelid
]);

let file = base;
const startName = file.indexOf('Injured Recoil');
const endName = file.indexOf('Ashamed Compress');
if (startName < 5 || endName < startName) throw new Error('Injured animation boundaries missing');
const start = startName - 5;
const end = endName - 5;
if (!file.subarray(start, startName).equals(Buffer.from([0x1f, 0x39, 0x12, 0x37, 0x0e])) ||
    !file.subarray(end, endName).equals(Buffer.from([0x1f, 0x39, 0x18, 0x37, 0x10]))) {
  throw new Error('Unexpected animation record layout');
}
file = Buffer.concat([file.subarray(0, start), animation, file.subarray(end)]);
// The Injured image node is drawn above the next art node, so it becomes the
// transparent eyelid overlay; the dormant next node holds the full state art.
file = replaceAsset(file,
  'archive/rook/legacy-state-art/rook-injured-transparent.png',
  'assets/rook/rook-injured-blink-overlay.png');
file = replaceAsset(file,
  'archive/rook/legacy-state-art/rook-ashamed-transparent.png',
  'assets/rook/rook-injured-transparent.png');

const destination = resolve(root, 'assets/rook/rook.riv');
writeFileSync(destination, file);
console.log(`Wrote ${destination} (${file.length} bytes, sha256 ${sha(file)})`);
