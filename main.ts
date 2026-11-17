// Brainrot Bazaar — the entrypoint for make.fun's roblox-brainrot-01 bounty.
// Node 22, standard library only. The game is the Rojo project in this
// directory, built into game.rbxl with:
//   rojo build default.project.json --output game.rbxl
// This program hands the game in: it copies game.rbxl, src/, screenshots/ and
// PLAY.json from beside this file to /output and writes /output/dossier.json,
// the summary the judge reads, with the vendored make.fun library
// (vendor/makefun-roblox.ts, the kit's copy, unchanged).
//
// The run must be deterministic: it runs twice and both runs must write the
// same bytes, so nothing here reads the clock, the environment or the network.
// Every name under /output starts with a letter, a digit or _ and holds only
// letters, digits, . _ and -; a file such as .gitkeep or .DS_Store anywhere
// under it fails the entry, so src/ and screenshots/ are copied without any
// name that starts with a dot, at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

/** Every file under a directory, relative paths, for the pre-flight checks. */
function listFiles(dir: string, base: string = dir): string[] {
  const found: string[] = [];
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) {
      found.push(...listFiles(path, base));
    } else {
      found.push(path.slice(base.length + 1));
    }
  }
  return found;
}

// Pre-flight: fail loudly (and identically on both runs) when a hand-in rule
// would fail the entry, instead of writing a bad /output.
const place = join(here, 'game.rbxl');
const placeStat = statSync(place);
if (placeStat.size > 32 * 1024 * 1024) {
  throw new Error(`game.rbxl is ${placeStat.size} bytes, over the 32 MiB cap`);
}
const play = JSON.parse(readFileSync(join(here, 'PLAY.json'), 'utf8')) as { url: string; place_id: number; universe_id: number };
if (typeof play.url !== 'string' || !play.url.startsWith('https://www.roblox.com/games/')) {
  throw new Error('PLAY.json url must be a https://www.roblox.com/games/<placeId> link');
}
const shotNames = listFiles(join(here, 'screenshots'));
if (shotNames.length < 3 || shotNames.length > 4) {
  throw new Error(`screenshots/ must hold 3 or 4 images, found ${shotNames.length}`);
}
for (const name of shotNames) {
  if (name.startsWith('.') || name.startsWith('-') || !/^[A-Za-z0-9._-]+$/.test(name)) {
    throw new Error(`screenshot name ${JSON.stringify(name)} is not allowed`);
  }
  if (statSync(join(here, 'screenshots', name)).size > 256 * 1024) {
    throw new Error(`screenshot ${name} is over the 256 KiB cap`);
  }
}
// The gate caps src/ at 400 files and 4 MiB; check both before copying.
const srcNames = listFiles(join(here, 'src'));
if (srcNames.length > 400) {
  throw new Error(`src/ holds ${srcNames.length} files, over the 400 cap`);
}
let srcBytes = 0;
for (const name of srcNames) {
  srcBytes += statSync(join(here, 'src', name)).size;
}
if (srcBytes > 4 * 1024 * 1024) {
  throw new Error(`src/ is ${srcBytes} bytes, over the 4 MiB cap`);
}

mkdirSync(out, { recursive: true });
copyFileSync(place, join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the
// bytes; the others refuse an entry the scorer would refuse (more than 4
// screenshots or one over 256 KiB; a place of more than 500000 instances,
// whose scripts' sources come to over 8 MiB or whose scripts' paths come to
// over 1048576 characters, in all).
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);
