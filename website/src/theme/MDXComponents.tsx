import MDXComponents from '@theme-original/MDXComponents';
import * as docs from '@site/src/components/Docs';

/** Makes the docs components available in every MDX page without imports. */
export default {
  ...MDXComponents,
  ...docs,
};
