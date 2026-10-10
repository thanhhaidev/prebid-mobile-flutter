// Keeps the native SDK version tables in sync with src/data/compatibility.json.
//
//   node scripts/sync-compatibility.mjs          rewrite the README tables
//   node scripts/sync-compatibility.mjs --check  fail if a table is stale or
//                                                the newest entry of a package
//                                                doesn't match its build files
//
// The newest entry of each package is checked against its pubspec.yaml
// (version, Flutter and Dart constraints), android/build.gradle.kts (Prebid
// artifact, minSdk), the podspec (Prebid pod, iOS platform) and Package.swift
// (Prebid package), so the docs can't drift from what the package resolves.
// A companion's `testedWith` (the Flutter ad plugin the example app runs on)
// is checked against the workspace pubspec.lock.
import {readFileSync, writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const site = join(dirname(fileURLToPath(import.meta.url)), '..');
const root = join(site, '..');
const check = process.argv.includes('--check');
const data = JSON.parse(readFileSync(join(site, 'src/data/compatibility.json'), 'utf8'));
const packages = Object.entries(data.packages);
const core = 'prebid_mobile_sdk';
const errors = [];

const read = (path) => readFileSync(join(root, path), 'utf8');
const match = (text, regex) => text.match(regex)?.[1] ?? null;
const iosRange = ({min, below}) => `>= ${min}, < ${below}`;

// ---------- Build files vs. the newest entry ----------

for (const [name, pkg] of packages) {
  const dir = `packages/${name}`;
  const latest = pkg.releases[0];
  const expect = (what, actual, wanted, file) => {
    if (actual !== wanted) {
      errors.push(`${name}: ${what} is ${actual ?? 'missing'} in ${file}, compatibility.json says ${wanted}`);
    }
  };

  const pubspec = read(`${dir}/pubspec.yaml`);
  expect('version', match(pubspec, /^version:\s*(\S+)/m), latest.version, 'pubspec.yaml');
  expect('the Flutter constraint', match(pubspec, /^\s+flutter:\s*'?([^'\n]+?)'?\s*$/m), latest.flutter, 'pubspec.yaml');
  expect('the Dart constraint', match(pubspec, /^\s+sdk:\s*'?([^'\n]+?)'?\s*$/m), latest.dart, 'pubspec.yaml');

  const gradle = read(`${dir}/android/build.gradle.kts`);
  const artifact = pkg.android.replace(/[.]/g, '\\.');
  expect('the Prebid Android version', match(gradle, new RegExp(`"${artifact}:([^"]+)"`)), latest.prebidAndroid, 'build.gradle.kts');
  expect('minSdk', Number(match(gradle, /minSdk\s*=\s*(\d+)/)), latest.androidMinSdk, 'build.gradle.kts');

  const podspec = read(`${dir}/ios/${name}.podspec`);
  const pod = podspec.match(new RegExp(`s\\.dependency\\s+'${pkg.ios}',\\s*'~>\\s*(\\d+)\\.\\d+',\\s*'>=\\s*([\\d.]+)'`));
  expect(
    'the Prebid iOS range',
    pod ? iosRange({min: pod[2], below: `${Number(pod[1]) + 1}.0`}) : null,
    iosRange(latest.prebidIos),
    'podspec',
  );
  expect('the iOS platform', match(podspec, /s\.platform\s*=\s*:ios,\s*'([^']+)'/), latest.iosMin, 'podspec');

  const spm = read(`${dir}/ios/${name}/Package.swift`);
  const from = match(spm, /prebid-mobile-ios\.git",\s*from:\s*"([^"]+)"/);
  expect(
    'the Prebid iOS range',
    from ? iosRange({min: from, below: `${Number(from.split('.')[0]) + 1}.0`}) : null,
    iosRange(latest.prebidIos),
    'Package.swift',
  );
  expect('the iOS platform', match(spm, /\.iOS\("([^"]+)"\)/), latest.iosMin, 'Package.swift');
}

// ---------- Flutter ad plugins vs. the example app ----------

const lock = read('pubspec.lock');
for (const [name, pkg] of packages) {
  const tested = pkg.releases[0].testedWith;
  if (!tested) continue;
  const resolved = match(lock, new RegExp(`^  ${tested.package}:\\n(?:    .*\\n)*?    version: "([^"]+)"`, 'm'));
  if (resolved !== tested.version) {
    errors.push(`${name}: the example resolves ${tested.package} ${resolved ?? '(missing)'} in pubspec.lock, compatibility.json says ${tested.version}`);
  }
}

// ---------- Tables ----------

const row = (cells) => `| ${cells.join(' | ')} |`;
const table = (head, rows) => [row(head), row(head.map(() => '---')), ...rows.map(row)].join('\n');
const code = (text) => `\`${text}\``;

function coreTable() {
  const {releases} = data.packages[core];
  return table(
    ['prebid_mobile_sdk', 'Prebid Android', 'Prebid iOS', 'Android', 'iOS', 'Flutter', 'Dart'],
    releases.map((r) => [
      r.version,
      code(r.prebidAndroid),
      code(iosRange(r.prebidIos)),
      `API ${r.androidMinSdk}+`,
      `${r.iosMin}+`,
      code(r.flutter),
      code(r.dart),
    ]),
  );
}

function companionTable(name) {
  const pkg = data.packages[name];
  return table(
    [name, `Prebid Android (${code(pkg.android.split(':')[1])})`, `Prebid iOS (${code(pkg.ios)})`, `${pkg.adSdk} Android`, `${pkg.adSdk} iOS`, 'Tested with'],
    pkg.releases.map((r) => [
      r.version,
      code(r.prebidAndroid),
      code(iosRange(r.prebidIos)),
      code(r.adSdkAndroid),
      code(r.adSdkIos),
      r.testedWith ? code(`${r.testedWith.package} ${r.testedWith.version}`) : '',
    ]),
  );
}

function latestTable() {
  return table(
    ['Package', 'Version', 'Prebid Android', 'Prebid iOS', 'Bundled ad SDK'],
    packages.map(([name, pkg]) => {
      const r = pkg.releases[0];
      return [
        `[${code(name)}](https://pub.dev/packages/${name})`,
        r.version,
        code(r.prebidAndroid),
        code(iosRange(r.prebidIos)),
        pkg.adSdk ? `${pkg.adSdk}: ${code(r.adSdkAndroid)} / ${code(r.adSdkIos)}` : 'none',
      ];
    }),
  );
}

const resolution =
  'Android resolves exactly the listed Prebid version. On iOS, CocoaPods and Swift Package Manager pick the newest PrebidMobile release in the range, so a fresh `pod install` can resolve a newer 3.x patch.';
const docsLink = 'Full mapping: [Compatibility](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/compatibility).';

const blocks = {
  'README.md': [latestTable(), resolution, docsLink],
  [`packages/${core}/README.md`]: [coreTable(), resolution, docsLink],
  ...Object.fromEntries(
    packages
      .filter(([name]) => name !== core)
      .map(([name]) => [
        `packages/${name}/README.md`,
        [companionTable(name), `Also requires the matching core \`${core}\` release. ${resolution}`, docsLink],
      ]),
  ),
};

const start = '<!-- compatibility:start -->';
const end = '<!-- compatibility:end -->';
const notice = '<!-- Generated from website/src/data/compatibility.json by website/scripts/sync-compatibility.mjs. Do not edit. -->';

for (const [path, parts] of Object.entries(blocks)) {
  const text = read(path);
  const from = text.indexOf(start);
  const to = text.indexOf(end);
  if (from === -1 || to === -1) {
    errors.push(`${path}: missing the ${start} / ${end} markers`);
    continue;
  }
  const updated = `${text.slice(0, from + start.length)}\n${notice}\n\n${parts.join('\n\n')}\n\n${text.slice(to)}`;
  if (updated === text) continue;
  if (check) {
    errors.push(`${path}: the compatibility table is stale; run \`node website/scripts/sync-compatibility.mjs\``);
  } else {
    writeFileSync(join(root, path), updated);
    console.log(`compatibility: updated ${path}`);
  }
}

if (errors.length) {
  console.error(errors.map((e) => `compatibility: ${e}`).join('\n'));
  process.exit(1);
}
console.log(`compatibility: ${packages.length} packages in sync`);
