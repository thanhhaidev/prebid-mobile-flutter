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
| `scripts/sync-changelog.mjs` | Builds `src/pages/changelog.md` from every package's CHANGELOG.md and its release tags |
| `src/pages/index.tsx` | Landing page |
| `src/css/custom.css` | Theme (colors, fonts, navbar, sidebar) |

`npm start` and `npm run build` run both scripts first (the compatibility one
in `--check` mode). After editing `compatibility.json`, run
`npm run compatibility` (or `dart run melos run compatibility` from the repo
root) to update the READMEs.

## Versions

The site has a single docs version that always describes the latest release
(the version label in the navbar comes from `compatibility.json`). Older
releases are covered by the changelog and the compatibility tables.

Deployment: `.github/workflows/docs.yml` builds and publishes to GitHub Pages.
