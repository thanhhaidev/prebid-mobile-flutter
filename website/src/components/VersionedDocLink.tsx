import type {ComponentProps, ReactNode} from 'react';
import {
  useActiveDocContext,
  useDocsPreferredVersion,
  useLatestVersion,
} from '@docusaurus/plugin-content-docs/client';
import DefaultNavbarItem from '@theme/NavbarItem/DefaultNavbarItem';

type Props = Omit<ComponentProps<typeof DefaultNavbarItem>, 'to'> & {
  /** The doc's path in a docs version, e.g. `banner` ('' for the docs home). */
  docPath: string;
};

/**
 * A navbar link to a doc in the docs version being read (or the last one
 * picked, or the latest), so reading an earlier release's docs stays in
 * them. `type: 'doc'` items would do it too, but every item of one sidebar
 * would then show as active.
 */
export default function VersionedDocLink({docPath, ...props}: Props): ReactNode {
  const {activeVersion} = useActiveDocContext(undefined);
  const {preferredVersion} = useDocsPreferredVersion(undefined);
  const latest = useLatestVersion(undefined);
  const version = activeVersion ?? preferredVersion ?? latest;
  return <DefaultNavbarItem {...props} to={docPath ? `${version.path}/${docPath}` : `${version.path}/`} />;
}
