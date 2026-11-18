// Victorious follows the user's close sunglasses/face screenshot while
// retaining Ready Rook's transparent brain silhouette and skin.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const ready = readFileSync(resolve(root, 'assets/rook/rook-victorious-ready-base.png'));
const encoded = ready.toString('base64');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="230" height="230" viewBox="0 0 1254 1254" role="img" aria-label="Victorious Rook wearing angled sunglasses">
  <defs>
    <radialGradient id="face-skin" cx="50%" cy="50%" r="55%">
      <stop offset="0%" stop-color="#F4A09C"/>
      <stop offset="75%" stop-color="#F4A09C"/>
      <stop offset="100%" stop-color="#F4A09C" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="lens" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#202224"/>
      <stop offset="100%" stop-color="#0B0C0D"/>
    </linearGradient>
    <clipPath id="left-lens"><path d="M273 488 Q408 453 590 475 L559 650 Q440 680 302 635 Z"/></clipPath>
    <clipPath id="right-lens"><path d="M626 477 Q812 455 994 506 L959 650 Q813 685 641 642 Z"/></clipPath>
  </defs>
  <image x="0" y="0" width="1254" height="1254" href="data:image/png;base64,${encoded}"/>

  <!-- Clear Ready's oversized eyes and smile to match the reference face. -->
  <ellipse cx="443" cy="570" rx="169" ry="169" fill="#F4A09C"/>
  <ellipse cx="765" cy="570" rx="169" ry="169" fill="#F4A09C"/>
  <ellipse cx="600" cy="768" rx="132" ry="95" fill="url(#face-skin)"/>
  <path d="M541 714 C573 738 643 740 680 708" fill="none" stroke="#171112" stroke-width="12" stroke-linecap="round"/>

  <!-- Brow arcs and slanted lenses follow the supplied face crop. -->
  <path d="M360 447 Q409 421 463 444 M748 444 Q807 416 862 448" fill="none" stroke="#A75C59" stroke-opacity=".8" stroke-width="11" stroke-linecap="round"/>
  <path d="M246 493 L281 483 M981 503 L1025 519" fill="none" stroke="#111111" stroke-width="18" stroke-linecap="round"/>
  <path d="M273 488 Q408 453 590 475 L559 650 Q440 680 302 635 Z" fill="url(#lens)" stroke="#101112" stroke-width="17" stroke-linejoin="round"/>
  <path d="M626 477 Q812 455 994 506 L959 650 Q813 685 641 642 Z" fill="url(#lens)" stroke="#101112" stroke-width="17" stroke-linejoin="round"/>
  <path d="M576 482 Q610 462 641 489" fill="none" stroke="#101112" stroke-width="19" stroke-linecap="round"/>
  <path d="M366 460 L433 449 L352 668 L310 653 Z" fill="#B8BFC1" opacity=".46" clip-path="url(#left-lens)"/>
  <path d="M723 459 L785 460 L705 678 L661 666 Z" fill="#B8BFC1" opacity=".46" clip-path="url(#right-lens)"/>

</svg>`;

const output = resolve(root, 'assets/rook/rook-victorious.svg');
writeFileSync(output, svg);
console.log(`Wrote ${output} (${Buffer.byteLength(svg)} bytes)`);

const blinkOverlay = `<svg xmlns="http://www.w3.org/2000/svg" width="1254" height="1254" viewBox="0 0 1254 1254">
  <path d="M393 555 Q433 562 473 555 M763 555 Q803 562 843 555" fill="none" stroke="#879092" stroke-opacity=".62" stroke-width="12" stroke-linecap="round"/>
</svg>`;
const blinkOutput = resolve(root, 'assets/rook/rook-victorious-eye-blink-overlay.svg');
writeFileSync(blinkOutput, blinkOverlay);
console.log(`Wrote ${blinkOutput} (${Buffer.byteLength(blinkOverlay)} bytes)`);
