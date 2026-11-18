// State 5 builds on the current transparent State 4 Rook, using only the
// user's fifth-pose screenshot and the current Ready–State 4 assets.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const base = readFileSync(resolve(root, 'assets/rook/rook-vomiting-base-green.png'));
const encoded = base.toString('base64');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="230" height="230" viewBox="0 0 1254 1254" role="img" aria-label="Vomiting Rook">
  <defs>
    <radialGradient id="mouth-skin" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#D6D8CB"/>
      <stop offset="77%" stop-color="#D6D8CB"/>
      <stop offset="100%" stop-color="#D6D8CB" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="lower-lids" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#C7C4B7"/>
      <stop offset="100%" stop-color="#D4D2C4"/>
    </linearGradient>
    <radialGradient id="eye-shadow" cx="50%" cy="38%" r="63%">
      <stop offset="0%" stop-color="#5C594E" stop-opacity=".42"/>
      <stop offset="60%" stop-color="#6D675B" stop-opacity=".22"/>
      <stop offset="100%" stop-color="#6D675B" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="mouth-dark" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1E1717"/>
      <stop offset="100%" stop-color="#482F30"/>
    </linearGradient>
    <linearGradient id="sickly-green" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#C4D6B5"/>
      <stop offset="100%" stop-color="#8FAA91"/>
    </linearGradient>
    <clipPath id="left-eye"><ellipse cx="443" cy="571" rx="136" ry="138"/></clipPath>
    <clipPath id="right-eye"><ellipse cx="765" cy="571" rx="137" ry="138"/></clipPath>
  </defs>
  <image x="0" y="0" width="1254" height="1254" href="data:image/png;base64,${encoded}"/>

  <!-- Narrow the eyes to tired slits while preserving the existing eye rings. -->
  <path d="M295 635 C379 621 496 581 592 578 L592 734 L295 734 Z" fill="url(#lower-lids)" clip-path="url(#left-eye)"/>
  <path d="M613 578 C710 582 829 622 919 637 L919 735 L613 735 Z" fill="url(#lower-lids)" clip-path="url(#right-eye)"/>
  <path d="M313 634 C390 619 485 591 579 584 M630 585 C725 591 827 622 904 635"
        fill="none" stroke="#271F1F" stroke-width="7" stroke-linecap="round"/>

  <!-- The fifth screenshot has deeper bags and creases than the fourth. -->
  <ellipse cx="433" cy="752" rx="153" ry="61" fill="url(#eye-shadow)"/>
  <ellipse cx="772" cy="752" rx="156" ry="61" fill="url(#eye-shadow)"/>
  <path d="M339 775 C382 805 447 808 495 771 M704 772 C754 812 834 805 879 767"
        fill="none" stroke="#6B675B" stroke-opacity=".72" stroke-width="6" stroke-linecap="round"/>
  <path d="M362 796 C407 818 464 809 489 791 M724 792 C766 819 827 813 855 789"
        fill="none" stroke="#8C8A78" stroke-opacity=".5" stroke-width="5" stroke-linecap="round"/>
  <path d="M329 450 C356 430 381 426 403 436 M805 435 C828 425 856 431 883 452"
        fill="none" stroke="#817E70" stroke-opacity=".5" stroke-width="6" stroke-linecap="round"/>

  <!-- A compact open retch and a small muted stream make the state legible. -->
  <ellipse cx="605" cy="792" rx="145" ry="89" fill="url(#mouth-skin)"/>
  <path d="M520 783 C541 763 571 756 598 769 C625 755 655 764 686 788 C671 819 639 833 604 831 C568 832 539 814 520 783 Z"
        fill="url(#mouth-dark)" stroke="#171313" stroke-width="10" stroke-linejoin="round"/>
  <path d="M574 816 C572 838 580 849 583 868 C586 886 580 909 594 919 C606 928 623 918 623 904 C622 888 613 876 615 859 C617 842 622 832 627 816 Z"
        fill="url(#sickly-green)" stroke="#597A62" stroke-width="5" stroke-linejoin="round"/>
  <path d="M594 918 C590 928 590 938 598 943 C607 947 617 939 615 930 C614 924 606 920 603 917 Z"
        fill="#A8C2A6" stroke="#64836B" stroke-width="4"/>
  <path d="M505 785 C494 793 490 806 496 818 M701 790 C714 799 717 811 711 821"
        fill="none" stroke="#817E6F" stroke-opacity=".65" stroke-width="7" stroke-linecap="round"/>
</svg>`;

const output = resolve(root, 'assets/rook/rook-vomiting.svg');
writeFileSync(output, svg);
console.log(`Wrote ${output} (${Buffer.byteLength(svg)} bytes)`);
