import {existsSync, readFileSync} from 'node:fs';
import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const repo = 'https://github.com/thanhhaidev/prebid-mobile-flutter';
const readJson = <T,>(path: string): T => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8')) as T;

// `docs/` describes the newest release. Earlier releases are snapshots that
// scripts/sync-versions.mjs builds from their git tags (versions.json).
const coreVersion = readJson<{packages: Record<string, {releases: {version: string}[]}>}>('./src/data/compatibility.json')
  .packages.prebid_mobile_sdk.releases[0].version;
const snapshots = existsSync(new URL('./versions.json', import.meta.url)) ? readJson<string[]>('./versions.json') : [];

/** Matches the given docs pages ('' is the intro page), in any docs version. */
const docsPage = (pages: string[]) =>
  `/docs/(?:[0-9][^/]*/)?(?:${pages.map((p) => p.replace(/-/g, '\\-')).join('|')})/?$`;
const guidePages = ['', 'configuration', 'privacy', 'targeting', 'events', 'debugging', 'platform-differences'];

const config: Config = {
  title: 'prebid_mobile_sdk',
  tagline: 'Unofficial Flutter plugin for Prebid Mobile header bidding, on Android and iOS.',
  favicon: 'img/favicon.svg',

  // GitHub Pages project site by default; set SITE_URL/BASE_URL for other hosts.
  url: process.env.SITE_URL ?? 'https://thanhhaidev.github.io',
  baseUrl: process.env.BASE_URL ?? '/prebid-mobile-flutter/',
  organizationName: 'thanhhaidev',
  projectName: 'prebid-mobile-flutter',
  // With `true`, static files such as search-index.json get redirected to a
  // trailing-slash URL by `docusaurus serve`.
  trailingSlash: false,

  onBrokenLinks: 'throw',
  markdown: {hooks: {onBrokenMarkdownLinks: 'throw'}},

  i18n: {defaultLocale: 'en', locales: ['en']},

  future: {v4: true, faster: true},

  headTags: [
    {tagName: 'link', attributes: {rel: 'preconnect', href: 'https://fonts.googleapis.com'}},
    {tagName: 'link', attributes: {rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: 'anonymous'}},
  ],
  stylesheets: [
    'https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600&family=Rethink+Sans:wght@400;500;600;700;800&display=swap',
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: 'docs',
          sidebarPath: './sidebars.ts',
          editUrl: `${repo}/tree/main/website/`,
          lastVersion: 'current',
          versions: {
            current: {label: `v${coreVersion}`},
            ...Object.fromEntries(snapshots.map((v) => [v, {label: `v${v}`, banner: 'unmaintained' as const}])),
          },
        },
        blog: false,
        theme: {customCss: './src/css/custom.css'},
      } satisfies Preset.Options,
    ],
  ],

  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        docsRouteBasePath: 'docs',
        indexBlog: false,
        highlightSearchTermsOnTargetPage: true,
        searchBarShortcutHint: true,
      },
    ],
  ],

  themeConfig: {
    image: 'img/social-card.svg',
    colorMode: {defaultMode: 'light', respectPrefersColorScheme: true},
    docs: {sidebar: {hideable: false, autoCollapseCategories: false}},
    navbar: {
      title: '',
      logo: {
        alt: 'prebid_mobile_sdk',
        src: 'img/logo.svg',
        srcDark: 'img/logo.svg',
      },
      items: [
        {type: 'html', position: 'left', value: '<span class="navbar-docs-badge">DOCS</span>'},
        // Plain links: `type: 'doc'` items of one sidebar all show as active.
        {to: '/docs/', label: 'Guide', position: 'left', activeBaseRegex: docsPage(guidePages)},
        {to: '/docs/banner', label: 'Ad formats', position: 'left', activeBaseRegex: docsPage(['banner', 'fullscreen', 'native', 'video'])},
        {to: '/docs/integrations', label: 'Ad servers', position: 'left', activeBaseRegex: docsPage(['integrations', 'original-api', 'gam', 'admob', 'max'])},
        {to: '/docs/compatibility', label: 'Compatibility', position: 'left', activeBaseRegex: docsPage(['compatibility'])},
        {to: '/changelog', label: 'Changelog', position: 'left'},
        // The docs version: a link to the release notes until there are
        // snapshots of earlier releases, then a version switcher.
        snapshots.length
          ? {
              type: 'docsVersionDropdown',
              position: 'right',
              className: 'navbar-version-dropdown',
              dropdownItemsAfter: [{to: '/changelog', label: 'Changelog'}],
            }
          : {to: '/changelog', label: `v${coreVersion}`, position: 'right', className: 'navbar-version-dropdown'},
        {href: repo, position: 'right', className: 'navbar-github', 'aria-label': 'GitHub repository'},
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Guide',
          items: [
            {label: 'Getting started', to: '/docs/'},
            {label: 'Configuration', to: '/docs/configuration'},
            {label: 'Compatibility', to: '/docs/compatibility'},
          ],
        },
        {
          title: 'Ad formats',
          items: [
            {label: 'Banner', to: '/docs/banner'},
            {label: 'Interstitial & rewarded', to: '/docs/fullscreen'},
            {label: 'Native', to: '/docs/native'},
          ],
        },
        {
          title: 'Packages',
          items: [
            {label: 'prebid_mobile_sdk', href: 'https://pub.dev/packages/prebid_mobile_sdk'},
            {label: 'prebid_mobile_sdk_gam', href: 'https://pub.dev/packages/prebid_mobile_sdk_gam'},
            {label: 'prebid_mobile_sdk_admob', href: 'https://pub.dev/packages/prebid_mobile_sdk_admob'},
            {label: 'prebid_mobile_sdk_max', href: 'https://pub.dev/packages/prebid_mobile_sdk_max'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'GitHub', href: repo},
            {label: 'Changelog', to: '/changelog'},
            {label: 'Prebid Mobile docs', href: 'https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html'},
          ],
        },
      ],
      copyright: 'An independent, community-maintained project: not affiliated with, endorsed by, or maintained by Prebid.org. MIT licensed · Built with Docusaurus.',
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.vsDark,
      additionalLanguages: ['dart', 'bash', 'yaml', 'kotlin', 'swift', 'groovy', 'ruby', 'json'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
