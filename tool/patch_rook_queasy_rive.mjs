// Rebuild the staged state-4 Rive asset from the verified Ready/Strained/Injured binary.
// The editable four-state source is assets/rook/scene.rml. Local Rive export
// requires an account, so this changes the already exported binary in place.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path));
const base = read('archive/rook/ready-strained-injured-before-queasy/rook.riv');
const expectedBase = '8dacba856c7745b8986e9208c16d2f1fdff7ca4b68ac08adbba2d2ee53946dfd';
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
  return Buffer.concat([
    haystack.subarray(0, at),
    replacement,
    haystack.subarray(at + needle.length),
  ]);
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
const animationName = Buffer.from('Queasy Blink');
const animation = Buffer.concat([
  Buffer.from([0x1f, 0x39]), varuint(360),
  Buffer.from([0x3b, 0x01, 0x37]), varuint(animationName.length), animationName, Buffer.from([0]),
  opacityTrack(0x26, [[0, 0]]), // Ready art
  opacityTrack(0x28, [[0, 0]]), // Strained art
  opacityTrack(0x2a, [[0, 0], [170, 0], [176, 1], [180, 1], [186, 0], [360, 0]]), // pale closed eyes
  opacityTrack(0x2c, [[0, 0]]), // Injured art
  opacityTrack(0x2e, [[0, 0]]), // dormant legacy art
  opacityTrack(0x30, [[0, 1]]), // state-4 art
  opacityTrack(0x02, [[0, 0]]), // Ready left eyelid
  opacityTrack(0x0b, [[0, 0]]), // Ready right eyelid
  opacityTrack(0x14, [[0, 0]]), // Strained left eyelid
  opacityTrack(0x1d, [[0, 0]]), // Strained right eyelid
]);

let file = base;
const startName = file.indexOf('Ashamed Compress');
const endName = file.indexOf('Recovering Lift');
if (startName < 5 || endName < startName) throw new Error('State-4 animation boundaries missing');
const start = startName - 5;
const end = endName - 5;
if (!file.subarray(start, startName).equals(Buffer.from([0x1f, 0x39, 0x18, 0x37, 0x10])) ||
    !file.subarray(end, endName).equals(Buffer.from([0x1f, 0x39, 0x12, 0x37, 0x0f]))) {
  throw new Error('Unexpected animation record layout');
}
file = Buffer.concat([file.subarray(0, start), animation, file.subarray(end)]);

// The old Ashamed boolean already drives the fourth animation state in this
// binary. Rename the input; all transition references use its numeric id.
file = replaceUnique(
  file,
  Buffer.concat([Buffer.from([0x09]), Buffer.from('isAshamed'), Buffer.from([0])]),
  Buffer.concat([Buffer.from([0x08]), Buffer.from('isQueasy'), Buffer.from([0])]),
);

// The dormant Victorious image node sits beneath the pale eyelid overlay in
// draw order, so it can carry the full state-4 artwork without moving Rook.
const oldPng = read('archive/rook/legacy-state-art/rook-victorious-transparent.png');
const newPng = read('assets/rook/rook-about-to-vomit-transparent.png');
file = replaceUnique(
  file,
  Buffer.concat([varuint(oldPng.length), oldPng]),
  Buffer.concat([varuint(newPng.length), newPng]),
);

const destination = resolve(root, 'assets/rook/rook.riv');
writeFileSync(destination, file);
console.log(`Wrote ${destination} (${file.length} bytes, sha256 ${sha(file)})`);
