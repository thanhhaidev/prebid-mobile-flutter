import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    {
      type: 'category',
      label: 'Getting Started',
      collapsible: false,
      items: ['index', 'configuration', 'compatibility'],
    },
    {
      type: 'category',
      label: 'Prebid Rendering',
      collapsible: false,
      items: ['banner', 'fullscreen', 'native', 'video'],
    },
    {
      type: 'category',
      label: 'Ad Servers',
      collapsible: false,
      items: ['integrations', 'original-api', 'gam', 'admob', 'max'],
    },
    {
      type: 'category',
      label: 'Data & Privacy',
      collapsible: false,
      items: ['privacy', 'targeting'],
    },
    {
      type: 'category',
      label: 'Reference',
      collapsible: false,
      items: ['events', 'debugging', 'platform-differences'],
    },
  ],
};

export default sidebars;
