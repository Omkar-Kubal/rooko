// Build a standalone Recovering Rive asset from the verified shared four-state
// binary. The default Ready animation is replaced with Recovering artwork and
// matching pink eyelids; the shared rook.riv remains unchanged.
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const read = (path) => readFileSync(resolve(root, path));
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
const source = read('assets/rook/rook.riv');
const expectedSource = '6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a';
if (sha(source) !== expectedSource) {
  throw new Error('Shared Rive binary changed; inspect before rebuilding Recovering');
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

function replaceUnique(file, oldBytes, newBytes) {
  const at = file.indexOf(oldBytes);
  if (at < 0 || file.indexOf(oldBytes, at + 1) >= 0) {
    throw new Error('Expected exactly one matching Rive record');
  }
  return Buffer.concat([
    file.subarray(0, at), newBytes, file.subarray(at + oldBytes.length),
  ]);
}

let file = source;
const ready = read('assets/rook/rook-ready-transparent.png');
const recovering = read('assets/rook/rook-recovering-transparent.png');
file = replaceUnique(
  file,
  Buffer.concat([varuint(ready.length), ready]),
  Buffer.concat([varuint(recovering.length), recovering]),
);

const oldLid = Buffer.from([0x9b, 0x9f, 0xf3, 0xff]); // #F39F9B, two Ready lids
const newLid = Buffer.from([0x9c, 0xa0, 0xf4, 0xff]); // #F4A09C, Recovering skin
const lids = file.indexOf(oldLid);
const secondLid = file.indexOf(oldLid, lids + oldLid.length);
if (lids < 0 || secondLid < 0 || file.indexOf(oldLid, secondLid + oldLid.length) >= 0) {
  throw new Error('Expected exactly two Ready eyelid colors');
}
newLid.copy(file, lids);
newLid.copy(file, secondLid);

const oldName = Buffer.from('Ready Blink');
const newName = Buffer.from('Recovering Blink');
file = replaceUnique(
  file,
  Buffer.concat([Buffer.from([0x37]), varuint(oldName.length), oldName, Buffer.from([0])]),
  Buffer.concat([Buffer.from([0x37]), varuint(newName.length), newName, Buffer.from([0])]),
);

const destination = resolve(root, 'assets/rook/rook-recovering.riv');
writeFileSync(destination, file);
console.log(`Wrote ${destination} (${file.length} bytes, sha256 ${sha(file)})`);
