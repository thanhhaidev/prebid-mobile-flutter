// Writes src/data/releases.json: the versions of every package that are on
// pub.dev, with their publish dates. The changelog page and the compatibility
// tables read it, so a version shows as released, with its date, only once
// pub.dev serves it. When pub.dev can't be reached (offline), the dates of the
// `<package>-v<version>` git tags are used instead.
import {execFileSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const site = join(dirname(fileURLToPath(import.meta.url)), '..');
const root = join(site, '..');
const packages = ['prebid_mobile_sdk', 'prebid_mobile_sdk_gam', 'prebid_mobile_sdk_admob', 'prebid_mobile_sdk_max'];

/** {latest, versions: {version: 'YYYY-MM-DD'}} from pub.dev; null when unreachable. */
async function fromPubDev(name) {
  try {
    const response = await fetch(`https://pub.dev/api/packages/${name}`, {
      headers: {accept: 'application/vnd.pub.v2+json'},
      signal: AbortSignal.timeout(15000),
    });
    // Not published yet.
    if (response.status === 404) return {latest: null, versions: {}};
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const body = await response.json();
    const versions = Object.fromEntries(
      body.versions.filter((v) => v.published).map((v) => [v.version, v.published.slice(0, 10)]),
    );
    return {latest: body.latest?.version ?? null, versions};
  } catch (error) {
    console.warn(`releases: pub.dev unreachable for ${name} (${error.message}); using git tag dates`);
    return null;
  }
}

/** The same shape from the package's git tags (tagger or commit date). */
function fromTags(name) {
  let lines = [];
  try {
    lines = execFileSync(
      'git',
      ['for-each-ref', '--sort=-creatordate', '--format=%(refname:short) %(creatordate:short)', `refs/tags/${name}-v*`],
      {cwd: root, stdio: ['ignore', 'pipe', 'ignore']},
    )
      .toString()
      .trim()
      .split('\n')
      .filter(Boolean);
  } catch {
    // Not a git checkout.
  }
  const versions = {};
  for (const line of lines) {
    const [tag, date] = line.split(' ');
    versions[tag.slice(`${name}-v`.length)] = date;
  }
  return {latest: Object.keys(versions)[0] ?? null, versions};
}

const releases = {};
for (const name of packages) {
  releases[name] = (await fromPubDev(name)) ?? fromTags(name);
}

writeFileSync(join(site, 'src/data/releases.json'), `${JSON.stringify(releases, null, 2)}\n`);
const count = Object.values(releases).reduce((n, r) => n + Object.keys(r.versions).length, 0);
console.log(`releases: ${count} published versions`);
