// Preserve the user-selected transparent Sleeping Rook pose exactly.
// The source PNG is the approved 230 px rendering; embedding it keeps the
// background transparent in the SVG while retaining the chosen details.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const source = readFileSync(resolve(root, 'assets/rook/rook-sleeping-selected-source.png'));
const encoded = source.toString('base64');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="230" height="230" viewBox="0 0 230 230" role="img" aria-label="Sleeping Rook with closed eyes, a cloud, and a small z">
  <image x="0" y="0" width="230" height="230" href="data:image/png;base64,${encoded}"/>
</svg>`;

const output = resolve(root, 'assets/rook/rook-sleeping.svg');
writeFileSync(output, svg);
console.log(`Wrote ${output} (${Buffer.byteLength(svg)} bytes)`);
