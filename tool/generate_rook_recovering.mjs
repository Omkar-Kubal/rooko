// Recovering uses only the approved State 2 art as its base. Its half-lidded
// eyes remain while a calm smile replaces the worried mouth.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const base = readFileSync(resolve(root, 'assets/rook/rook-strained-transparent.png'));
const encoded = base.toString('base64');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="230" height="230" viewBox="0 0 1254 1254" role="img" aria-label="Recovering Rook with resting eyes and a small smile">
  <defs>
    <radialGradient id="mouth-skin">
      <stop offset="0%" stop-color="#F4A09C"/>
      <stop offset="76%" stop-color="#F4A09C"/>
      <stop offset="100%" stop-color="#F4A09C" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <image x="0" y="0" width="1254" height="1254" href="data:image/png;base64,${encoded}"/>

  <!-- Calm the worried State 2 mouth without changing the brain silhouette. -->
  <ellipse cx="606" cy="766" rx="130" ry="108" fill="url(#mouth-skin)"/>
  <path d="M536 763 C563 789 581 794 605 794 C629 794 648 788 674 762"
        fill="none" stroke="#171112" stroke-width="12" stroke-linecap="round"/>
  <!-- A faint remnant of fatigue keeps this distinct from fully Ready. -->
  <path d="M351 731 C391 754 447 757 488 735 M722 735 C764 759 822 754 865 729"
        fill="none" stroke="#9B7773" stroke-opacity=".45" stroke-width="6" stroke-linecap="round"/>
</svg>`;

const output = resolve(root, 'assets/rook/rook-recovering.svg');
writeFileSync(output, svg);
console.log(`Wrote ${output} (${Buffer.byteLength(svg)} bytes)`);
