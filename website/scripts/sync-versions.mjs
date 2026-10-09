// Snapshots the docs of every earlier prebid_mobile_sdk release. For each core
// version that pub.dev serves (src/data/releases.json) and that has a
// `prebid_mobile_sdk-v<version>` tag, the docs and sidebar at that tag become a
// Docusaurus docs version at /docs/<version>/. The version in `docs/` (the
// newest entry in compatibility.json) is the current docs, so it gets no
// snapshot. Writes versions.json, versioned_docs/ and versioned_sidebars/, all
// untracked: a successful release adds its snapshot on the next docs build.
import {execFileSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import ts from 'typescript';

const site = join(dirname(fileURLToPath(import.meta.url)), '..');
const root = join(site, '..');
const name = 'prebid_mobile_sdk';

const releases = JSON.parse(readFileSync(join(site, 'src/data/releases.json'), 'utf8'));
const compatibility = JSON.parse(readFileSync(join(site, 'src/data/compatibility.json'), 'utf8'));
const current = compatibility.packages[name].releases[0].version;

const git = (args, options = {}) =>
  execFileSync('git', args, {cwd: root, stdio: ['ignore', 'pipe', 'ignore'], ...options});

function hasDocs(tag) {
  try {
    git(['cat-file', '-e', `${tag}:website/docs`]);
    git(['cat-file', '-e', `${tag}:website/sidebars.ts`]);
    return true;
  } catch {
    return false;
  }
}

/** The sidebars object of sidebars.ts at `tag`, as versioned_sidebars JSON. */
async function sidebarsAt(tag) {
  const source = git(['show', `${tag}:website/sidebars.ts`]).toString();
  const {outputText} = ts.transpileModule(source, {
    compilerOptions: {module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022},
  });
  const module = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`);
  return module.default;
}

/** Points absolute docs links at the snapshot instead of the current docs. */
function pinLinks(dir, version) {
  for (const entry of readdirSync(dir, {withFileTypes: true})) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      pinLinks(path, version);
    } else if (/\.mdx?$/.test(entry.name)) {
      const text = readFileSync(path, 'utf8');
      writeFileSync(path, text.replace(/\]\(\/docs\//g, `](/docs/${version}/`));
    }
  }
}

const semverDesc = (a, b) => {
  const pa = a.split(/[.+-]/).map(Number);
  const pb = b.split(/[.+-]/).map(Number);
  for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pb[i] - pa[i];
  return 0;
};

for (const path of ['versions.json', 'versioned_docs', 'versioned_sidebars']) {
  rmSync(join(site, path), {recursive: true, force: true});
}

const versions = Object.keys(releases[name]?.versions ?? {})
  .filter((version) => version !== current && !version.includes('-'))
  .sort(semverDesc);

const snapshots = [];
for (const version of versions) {
  const tag = `${name}-v${version}`;
  if (!hasDocs(tag)) {
    console.warn(`versions: skipping ${version} (no ${tag} tag with website/docs)`);
    continue;
  }
  const target = join(site, 'versioned_docs', `version-${version}`);
  const scratch = mkdtempSync(join(tmpdir(), 'docs-'));
  try {
    const archive = git(['archive', '--format=tar', tag, 'website/docs'], {maxBuffer: 64 * 1024 * 1024});
    execFileSync('tar', ['-x', '-C', scratch], {input: archive});
    mkdirSync(dirname(target), {recursive: true});
    execFileSync('cp', ['-R', join(scratch, 'website/docs'), target]);
  } finally {
    rmSync(scratch, {recursive: true, force: true});
  }
  pinLinks(target, version);
  mkdirSync(join(site, 'versioned_sidebars'), {recursive: true});
  writeFileSync(
    join(site, 'versioned_sidebars', `version-${version}-sidebars.json`),
    `${JSON.stringify(await sidebarsAt(tag), null, 2)}\n`,
  );
  snapshots.push(version);
}

if (snapshots.length) writeFileSync(join(site, 'versions.json'), `${JSON.stringify(snapshots, null, 2)}\n`);
console.log(`versions: current v${current}${snapshots.length ? `, snapshots ${snapshots.join(', ')}` : ''}`);
