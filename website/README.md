# prebid-mobile-flutter docs

The documentation site, built with [Docusaurus](https://docusaurus.io/) and
published at <https://thanhhaidev.github.io/prebid-mobile-flutter/>.

## Develop

Requires Node 20+.

```bash
cd website
npm install
npm start          # regenerates the changelog, then serves on http://localhost:3000
```

## Build

```bash
npm run build      # output in build/
npm run serve      # preview the build
```

By default the site is built for GitHub Pages at `/prebid-mobile-flutter/`.
For another host, set `SITE_URL` and `BASE_URL`, e.g. `BASE_URL=/ npm run build`.

## Structure

| Path | Content |
| --- | --- |
| `docs/` | MDX pages; the components in `src/components/Docs` are available without imports |
| `src/data/compatibility.json` | Native Prebid SDK versions per package release: the source of the compatibility tables |
| `scripts/sync-compatibility.mjs` | Writes those tables into the package READMEs and checks them against the build files (`--check`) |
| `scripts/sync-releases.mjs` | Fetches the published versions and their dates from pub.dev into `src/data/releases.json` |
| `scripts/sync-versions.mjs` | Snapshots the docs of earlier core releases from their git tags (`versions.json`, `versioned_docs/`) |
| `scripts/sync-changelog.mjs` | Builds `src/pages/changelog.md` from every package's CHANGELOG.md, with the pub.dev release dates |
| `src/pages/index.tsx` | Landing page |
| `src/css/custom.css` | Theme (colors, fonts, navbar, sidebar) |

`npm start` and `npm run build` run these scripts first (the compatibility one
in `--check` mode); their output is not committed. After editing `compatibility.json`, run
`npm run compatibility` (or `dart run melos run compatibility` from the repo
root) to update the READMEs.

## Versions

`docs/` describes the newest release (the navbar label comes from
`compatibility.json`). Each earlier `prebid_mobile_sdk` release that is on
pub.dev gets a docs version built from its git tag, at `/docs/<version>/`, and
the navbar badge becomes a version dropdown. A version shows as released, with
its date, only once pub.dev serves it. See [RELEASING.md](../RELEASING.md#documentation).

Deployment: `.github/workflows/docs.yml` builds and publishes to GitHub Pages.
