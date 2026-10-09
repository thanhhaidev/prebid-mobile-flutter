import React, {type ReactNode} from 'react';
import Head from '@docusaurus/Head';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {useLocation} from '@docusaurus/router';

function SeoHead() {
  const {siteConfig} = useDocusaurusContext();
  const location = useLocation();
  const basePath = siteConfig.baseUrl.replace(/\/$/, '');
  const pathname = location.pathname
    .replace(new RegExp(`^${basePath}`), '')
    .replace(/^\/|\/$/g, '');
  const home = pathname === '';
  const slug = pathname.replace(/^docs\//, '').replace(/-/g, ' ');
  const pageName = home ? 'Header bidding for Flutter' : slug ? slug.replace(/\b\w/g, (letter) => letter.toUpperCase()) : 'Documentation';
  const title = `${pageName} | prebid_mobile_sdk`;
  const description = home
    ? 'Unofficial Prebid Mobile header bidding plugin for Flutter: banner, interstitial, rewarded, native and video ads on Android and iOS, with GAM, AdMob and AppLovin MAX.'
    : `prebid_mobile_sdk (unofficial Prebid Mobile plugin for Flutter) documentation: ${pageName.toLowerCase()}.`;
  const url = `${siteConfig.url}${siteConfig.baseUrl}${pathname}`;
  const image = `${siteConfig.url}${siteConfig.baseUrl}img/social-card.svg`;
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': home ? 'SoftwareApplication' : 'TechArticle',
    name: title,
    description,
    url,
    image,
    ...(home
      ? {applicationCategory: 'DeveloperApplication', operatingSystem: 'Android, iOS', programmingLanguage: ['Dart', 'Flutter']}
      : {isPartOf: {'@type': 'WebSite', name: 'prebid_mobile_sdk', url: `${siteConfig.url}${siteConfig.baseUrl}`}}),
  };
  return (
    <Head>
      <meta property="og:type" content={home ? 'website' : 'article'} />
      <meta property="og:title" content={title} />
      <meta property="og:description" content={description} />
      <meta property="og:url" content={url} />
      <meta property="og:image" content={image} />
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={title} />
      <meta name="twitter:description" content={description} />
      <link rel="canonical" href={url} />
      <script type="application/ld+json">{JSON.stringify(jsonLd)}</script>
    </Head>
  );
}

export default function Root({children}: {children: ReactNode}) {
  return (
    <>
      <SeoHead />
      {children}
    </>
  );
}
