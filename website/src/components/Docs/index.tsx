import React, {type ReactNode} from 'react';
import Link from '@docusaurus/Link';
import {useLayoutDoc} from '@docusaurus/plugin-content-docs/client';
import compatibility from '@site/src/data/compatibility.json';
import styles from './styles.module.css';

export function Steps({children}: {children: ReactNode}) {
  return <div className={styles.steps}>{children}</div>;
}

export function Step({title, children}: {title: string; children: ReactNode}) {
  return (
    <div className={styles.step}>
      <div className={styles.stepTitle}>{title}</div>
      {children}
    </div>
  );
}

/** A grid of link cards. */
export function Cards({children}: {children: ReactNode}) {
  return <div className={styles.cards}>{children}</div>;
}

export function Card({
  to,
  icon,
  title,
  tags = [],
  children,
}: {
  to: string;
  icon: string;
  title: string;
  tags?: string[];
  children: ReactNode;
}) {
  // Resolve against the docs version being viewed.
  const docId = to.replace(/^\/docs\/?/, '').replace(/\/$/, '') || 'index';
  const doc = useLayoutDoc(docId);

  return (
    <Link to={doc?.path ?? to} className={styles.card}>
      <span className={styles.cardIcon}>{icon}</span>
      <span className={styles.cardTitle}>{title}</span>
      <span className={styles.cardText}>{children}</span>
      <span className={styles.cardFooter}>
        {tags.map((tag) => (
          <span key={tag} className={styles.tag}>
            {tag}
          </span>
        ))}
        <span className={styles.arrow}>↗</span>
      </span>
    </Link>
  );
}

/** "Android only" / "iOS only" marker for platform-specific APIs. */
export function Only({platform}: {platform: 'android' | 'ios'}) {
  return (
    <span className={styles.platform} data-platform={platform}>
      {platform === 'ios' ? 'iOS only' : 'Android only'}
    </span>
  );
}

// ---------- Compatibility ----------

type Range = {min: string; below: string};
type Release = {
  version: string;
  prebidAndroid: string;
  prebidIos: Range;
  androidMinSdk: number;
  iosMin: string;
  flutter: string;
  dart: string;
  adSdkAndroid?: string;
  adSdkIos?: string;
};
type Package = {
  title: string;
  android: string;
  ios: string;
  adSdk?: string;
  releases: Release[];
};

const packages = compatibility.packages as Record<string, Package>;
const range = ({min, below}: Range) => `>= ${min}, < ${below}`;

function Version({release, latest}: {release: Release; latest: boolean}) {
  return (
    <span className={styles.version}>
      {release.version}
      {latest && <span className={styles.latest}>latest</span>}
    </span>
  );
}

/** Every release of one package and the native SDKs it resolves. */
export function CompatibilityTable({name}: {name: string}) {
  const pkg = packages[name];
  const companion = Boolean(pkg.adSdk);
  return (
    <div className={styles.tableWrap}>
      <table>
        <thead>
          <tr>
            <th>{name}</th>
            <th>Prebid Android</th>
            <th>Prebid iOS</th>
            {companion ? (
              <>
                <th>Ad SDK Android</th>
                <th>Ad SDK iOS</th>
              </>
            ) : (
              <>
                <th>Android</th>
                <th>iOS</th>
                <th>Flutter</th>
              </>
            )}
          </tr>
        </thead>
        <tbody>
          {pkg.releases.map((r, i) => (
            <tr key={r.version}>
              <td>
                <Version release={r} latest={i === 0} />
              </td>
              <td>
                <code>{r.prebidAndroid}</code>
              </td>
              <td className={styles.nowrap}>
                <code>{range(r.prebidIos)}</code>
              </td>
              {companion ? (
                <>
                  <td>
                    <code>{r.adSdkAndroid}</code>
                  </td>
                  <td>
                    <code>{r.adSdkIos}</code>
                  </td>
                </>
              ) : (
                <>
                  <td className={styles.nowrap}>API {r.androidMinSdk}+</td>
                  <td className={styles.nowrap}>{r.iosMin}+</td>
                  <td>
                    <code>{r.flutter}</code>
                  </td>
                </>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** The latest release of every package and the native artifacts it uses. */
export function ArtifactTable() {
  return (
    <div className={styles.tableWrap}>
      <table>
        <thead>
          <tr>
            <th>Package</th>
            <th>Android artifact</th>
            <th>iOS pod / SPM product</th>
            <th>Bundled ad SDK</th>
          </tr>
        </thead>
        <tbody>
          {Object.entries(packages).map(([name, pkg]) => {
            const r = pkg.releases[0];
            return (
              <tr key={name}>
                <td>
                  <a href={`https://pub.dev/packages/${name}`}>
                    <code>{name}</code>
                  </a>{' '}
                  <span className={styles.version}>{r.version}</span>
                </td>
                <td>
                  <code>
                    {pkg.android}:{r.prebidAndroid}
                  </code>
                </td>
                <td>
                  <code>{pkg.ios}</code> <code>{range(r.prebidIos)}</code>
                </td>
                <td>{pkg.adSdk ? `${pkg.adSdk}` : 'None'}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/** Version of a package's latest release, for inline use in MDX. */
export function LatestVersion({name = 'prebid_mobile_sdk'}: {name?: string}) {
  return <>{packages[name].releases[0].version}</>;
}

/** Prebid SDK versions of the core package's latest release. */
export function PrebidVersion({platform}: {platform: 'android' | 'ios'}) {
  const r = packages.prebid_mobile_sdk.releases[0];
  return <code>{platform === 'android' ? r.prebidAndroid : range(r.prebidIos)}</code>;
}
