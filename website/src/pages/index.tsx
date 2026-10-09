import React, {useState, type ReactNode} from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import {Card, Cards} from '@site/src/components/Docs';
import compatibility from '@site/src/data/compatibility.json';
import styles from './index.module.css';

type Example = {
  tab: string;
  file: string;
  code: ReactNode;
  events: string;
};

const s = (text: string) => <span className={styles.str}>{text}</span>;
const f = (text: string) => <span className={styles.fn}>{text}</span>;
const k = (text: string) => <span className={styles.kw}>{text}</span>;
const c = (text: string) => <span className={styles.cm}>{text}</span>;

const EXAMPLES: Example[] = [
  {
    tab: 'Banner',
    file: 'banner.dart',
    code: (
      <>
        {f('PrebidBannerAd')}({'\n'}
        {'  '}configId: {s("'prebid-demo-banner-320-50'")},{'\n'}
        {'  '}width: {s('320')},{'\n'}
        {'  '}height: {s('50')},{'\n'}
        {'  '}refreshIntervalSeconds: {s('30')},{'\n'}
        {'  '}listener: {f('PrebidBannerAdListener')}({'\n'}
        {'    '}onAdLoaded: () {'=>'} {f('debugPrint')}({s("'loaded'")}),{'\n'}
        {'  '}),{'\n'}
        )
      </>
    ),
    events: 'onAdLoaded → onAdDisplayed → onAdClicked',
  },
  {
    tab: 'Interstitial',
    file: 'interstitial.dart',
    code: (
      <>
        {k('final')} ad = {f('PrebidInterstitialAd')}({'\n'}
        {'  '}configId: {s("'prebid-demo-display-interstitial-320-480'")},{'\n'}
        {'  '}adFormats: {'{'}
        {f('AdFormat')}.banner, {f('AdFormat')}.video{'}'},{'\n'}
        {'  '}listener: {f('PrebidInterstitialAdListener')}({'\n'}
        {'    '}onAdLoaded: () {'=>'} ad.{f('show')}(),{'\n'}
        {'    '}onAdClosed: () {'=>'} ad.{f('destroy')}(),{'\n'}
        {'  '}),{'\n'}
        );{'\n'}
        {k('await')} ad.{f('loadAd')}();
      </>
    ),
    events: 'onAdLoaded → onAdDisplayed → onAdClosed',
  },
  {
    tab: 'Native',
    file: 'native.dart',
    code: (
      <>
        {k('final')} ad = {f('PrebidNativeAd')}({'\n'}
        {'  '}configId: {s("'prebid-demo-banner-native-styles'")},{'\n'}
        {'  '}listener: {f('PrebidNativeAdListener')}({'\n'}
        {'    '}onAdLoaded: (response) {'=>'} {f('setState')}(() {'=>'} loaded = {k('true')}),{'\n'}
        {'  '}),{'\n'}
        )..{f('loadAd')}();{'\n\n'}
        {c('// build(): rendered natively, impressions and clicks tracked')}
        {'\n'}
        {k('if')} (loaded) {f('PrebidNativeAdView')}(ad: ad)
      </>
    ),
    events: 'onAdLoaded → onAdImpression → onAdClicked',
  },
  {
    tab: 'GAM',
    file: 'original_api.dart',
    code: (
      <>
        {c('// Prebid runs the auction, Google Ad Manager renders')}
        {'\n'}
        {k('final')} unit = {f('PrebidBannerAdUnit')}({'\n'}
        {'  '}configId: {s("'your-config-id'")},{'\n'}
        {'  '}sizes: {k('const')} [{f('Size')}({s('300')}, {s('250')})],{'\n'}
        );{'\n'}
        {k('final')} bid = {k('await')} unit.{f('fetchDemand')}();{'\n\n'}
        {f('AdManagerBannerAd')}({'\n'}
        {'  '}request: {f('AdManagerAdRequest')}({'\n'}
        {'    '}customTargeting: bid.targetingKeywords ?? {'{}'},{'\n'}
        {'  '}),{'\n'}
        {'  '}...{'\n'}
        ).{f('load')}();
      </>
    ),
    events: "hb_pb, hb_bidder, hb_cache_id … → GAM's customTargeting",
  },
];

function CodePanel() {
  const [index, setIndex] = useState(0);
  const example = EXAMPLES[index];
  return (
    <div className={styles.panel}>
      <div className={styles.tabs}>
        {EXAMPLES.map((e, i) => (
          <button key={e.tab} type="button" className={i === index ? styles.tabActive : styles.tab} onClick={() => setIndex(i)}>
            {e.tab}
          </button>
        ))}
        <span className={styles.file}>{example.file}</span>
      </div>
      <pre className={styles.code}>{example.code}</pre>
      <div className={styles.result}>
        <span>→</span>
        <span className={styles.resultValue}>{example.events}</span>
        <span className={styles.platforms}>
          <span>Android</span>
          <span>iOS</span>
        </span>
      </div>
    </div>
  );
}

const core = compatibility.packages.prebid_mobile_sdk.releases[0];

function Hero() {
  return (
    <header className={styles.hero}>
      <div className={styles.stripe} />
      <div className={styles.stripe2} />
      <div className={`container ${styles.heroInner}`}>
        <div>
          <Link className={styles.badge} to="/docs/compatibility">
            Unofficial Flutter plugin <span>Prebid Mobile {core.prebidAndroid} →</span>
          </Link>
          <h1 className={styles.title}>
            Header bidding for Flutter, <em>on Android and iOS</em>
          </h1>
          <p className={styles.subtitle}>
            Run Prebid auctions from Dart: banner, interstitial, rewarded, native and video ads rendered by Prebid, or
            handed to Google Ad Manager, AdMob or AppLovin MAX.
          </p>
          <div className={styles.actions}>
            <Link className={styles.primary} to="/docs/">
              Get started ↗
            </Link>
            <Link className={styles.secondary} to="/docs/compatibility">
              Native SDK versions
            </Link>
          </div>
          <div className={styles.install}>
            $ <code>flutter pub add prebid_mobile_sdk</code>
          </div>
          <p className={styles.disclaimer}>
            Community project, not affiliated with or endorsed by Prebid.org. It wraps the official Prebid Mobile
            SDKs.
          </p>
        </div>
        <CodePanel />
      </div>
    </header>
  );
}

const PACKAGES: {name: string; text: string}[] = [
  {name: 'prebid_mobile_sdk', text: 'Core plugin: Prebid-rendered ads, the Original API keyword handoff, targeting and privacy.'},
  {name: 'prebid_mobile_sdk_gam', text: 'Google Ad Manager renders through Prebid’s GAM event handlers.'},
  {name: 'prebid_mobile_sdk_admob', text: 'Prebid demand inside AdMob mediation, through Prebid’s AdMob adapters.'},
  {name: 'prebid_mobile_sdk_max', text: 'Prebid demand inside AppLovin MAX mediation, through Prebid’s MAX adapters.'},
];

const FEATURES: [string, string, string][] = [
  ['5', 'Ad formats', 'Banner, interstitial, rewarded, native and in-stream video, plus multiformat requests.'],
  ['3', 'Ad servers', 'Google Ad Manager rendering, AdMob and AppLovin MAX mediation, or your own keyword handoff.'],
  ['2.6', 'OpenRTB', 'plcmt, battr, start delay and every video signal; user IDs in user.eids.'],
  ['1:1', 'Native parity', 'Same callbacks and result codes on both platforms; differences are documented.'],
];

export default function Home(): ReactNode {
  return (
    <Layout
      title="Header bidding for Flutter"
      description="prebid_mobile_sdk: unofficial Prebid Mobile header bidding for Flutter on Android and iOS, with Google Ad Manager, AdMob and AppLovin MAX."
    >
      <Hero />
      <main>
        <section className={styles.section}>
          <div className="container">
            <h2 className={styles.sectionTitle}>Explore the docs</h2>
            <p className={styles.sectionText}>From the first banner to a full ad server integration.</p>
            <Cards>
              <Card to="/docs/" icon="▶" title="Getting started" tags={['install', 'init']}>
                Install, initialize the SDK and show a first banner.
              </Card>
              <Card to="/docs/banner" icon="▭" title="Banner" tags={['multisize', 'video']}>
                Display and outstream video banners with auto-refresh.
              </Card>
              <Card to="/docs/fullscreen" icon="⛶" title="Interstitial & rewarded" tags={['load', 'show']}>
                Fullscreen display and video, rewards and controls.
              </Card>
              <Card to="/docs/native" icon="▤" title="Native" tags={['assets', 'tracking']}>
                Native rendering with impression and click tracking.
              </Card>
              <Card to="/docs/integrations" icon="⇄" title="Ad servers" tags={['GAM', 'AdMob', 'MAX']}>
                Pick between Prebid rendering, keyword handoff and mediation.
              </Card>
              <Card to="/docs/privacy" icon="⚑" title="Privacy" tags={['GDPR', 'CCPA', 'COPPA']}>
                Consent signals and what the SDK reads on its own.
              </Card>
              <Card to="/docs/compatibility" icon="⌗" title="Compatibility" tags={['Prebid', 'versions']}>
                The native Prebid SDK behind every release.
              </Card>
              <Card to="/docs/debugging" icon="⌕" title="Debugging" tags={['bid inspector']}>
                Inspect bid requests, stored responses and logs.
              </Card>
            </Cards>
          </div>
        </section>
        <section className={styles.sectionAlt}>
          <div className="container">
            <h2 className={styles.sectionTitle}>Four packages</h2>
            <p className={styles.sectionText}>Add only the ad SDKs you use: the core plugin depends on Prebid alone.</p>
            <div className={styles.packages}>
              {PACKAGES.map(({name, text}) => {
                const pkg = (compatibility.packages as Record<string, {releases: {version: string; prebidAndroid: string; prebidIos: {min: string}}[]}>)[name];
                const r = pkg.releases[0];
                return (
                  <div key={name} className={styles.package}>
                    <a href={`https://pub.dev/packages/${name}`}>
                      <code>{name}</code>
                    </a>
                    <p>{text}</p>
                    <div className={styles.packageVersions}>
                      v{r.version} · Prebid Android {r.prebidAndroid} · iOS {r.prebidIos.min}+
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>
        <section className={styles.section}>
          <div className="container">
            <div className={styles.features}>
              {FEATURES.map(([stat, title, text]) => (
                <div key={title} className={styles.feature}>
                  <div className={styles.stat}>{stat}</div>
                  <h3>{title}</h3>
                  <p>{text}</p>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
