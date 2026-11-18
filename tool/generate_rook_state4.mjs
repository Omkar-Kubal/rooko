// State 4 asset uses only the current Injured artwork as its base; the user's
// five-pose screenshot supplied the queasy eye bags and pressed, wavering mouth.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const base = readFileSync(resolve(root, 'assets/rook/rook-injured-transparent.png'));
const encoded = base.toString('base64');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="230" height="230" viewBox="0 0 1254 1254" role="img" aria-label="Queasy Rook">
  <defs>
    <radialGradient id="mouth-skin" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#E4D1CE"/>
      <stop offset="78%" stop-color="#E4D1CE"/>
      <stop offset="100%" stop-color="#E4D1CE" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="eye-bag" cx="50%" cy="35%" r="65%">
      <stop offset="0%" stop-color="#755B59" stop-opacity=".42"/>
      <stop offset="55%" stop-color="#846C69" stop-opacity=".23"/>
      <stop offset="100%" stop-color="#846C69" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="lip-shadow" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#604442" stop-opacity=".65"/>
      <stop offset="100%" stop-color="#977A77" stop-opacity=".28"/>
    </linearGradient>
  </defs>
  <image x="0" y="0" width="1254" height="1254" href="data:image/png;base64,${encoded}"/>

  <!-- Deepened tired eye bags, within the existing facial silhouette. -->
  <ellipse cx="433" cy="747" rx="151" ry="48" fill="url(#eye-bag)"/>
  <ellipse cx="771" cy="747" rx="154" ry="48" fill="url(#eye-bag)"/>
  <path d="M342 735 C375 768 440 777 490 740" fill="none" stroke="#806663" stroke-opacity=".64" stroke-width="6" stroke-linecap="round"/>
  <path d="M706 740 C756 780 832 770 872 727" fill="none" stroke="#806663" stroke-opacity=".64" stroke-width="6" stroke-linecap="round"/>
  <path d="M358 756 C392 777 449 778 475 755 M724 757 C765 781 823 774 853 748" fill="none" stroke="#A18A86" stroke-opacity=".42" stroke-width="5" stroke-linecap="round"/>

  <!-- Replace only the state-three frown with a pressed, wavering grimace. -->
  <ellipse cx="604" cy="773" rx="135" ry="68" fill="url(#mouth-skin)"/>
  <path d="M505 791 C526 767 554 755 578 763 C600 751 626 754 648 764 C672 759 694 772 707 795"
        fill="none" stroke="#171414" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M529 803 C551 789 579 790 600 801 C624 790 658 790 683 807"
        fill="none" stroke="url(#lip-shadow)" stroke-width="8" stroke-linecap="round"/>
  <path d="M498 790 C491 800 491 810 496 816 M715 793 C723 802 723 811 719 817"
        fill="none" stroke="#8D7270" stroke-opacity=".5" stroke-width="6" stroke-linecap="round"/>
</svg>`;

const output = resolve(root, 'assets/rook/rook-about-to-vomit.svg');
writeFileSync(output, svg);
console.log(`Wrote ${output} (${Buffer.byteLength(svg)} bytes)`);
