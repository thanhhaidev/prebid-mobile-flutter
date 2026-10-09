# Security policy

## Supported versions

Security fixes are released for the latest minor version of each package.

| Package | Supported |
| --- | --- |
| `prebid_mobile_sdk` 1.x | Yes |
| `prebid_mobile_sdk_gam` 1.x | Yes |
| `prebid_mobile_sdk_admob` 1.x | Yes |
| `prebid_mobile_sdk_max` 1.x | Yes |

## Reporting a vulnerability

Please **don't** open a public issue. Report it privately through
[GitHub's vulnerability reporting](https://github.com/thanhhaidev/prebid-mobile-flutter/security/advisories/new)
with:

- the affected package and version,
- what an attacker can do, and how to reproduce it,
- any fix you have in mind.

You'll get an answer within a week. Once a fix is released, the advisory is
published with credit to you, unless you'd rather stay anonymous.

## Scope

This policy covers the code in this repository: the Dart, Kotlin and Swift
of the Flutter plugins. Vulnerabilities in the native Prebid Mobile SDKs or
Prebid Server should be reported to Prebid
([prebid-mobile-android](https://github.com/prebid/prebid-mobile-android/security),
[prebid-mobile-ios](https://github.com/prebid/prebid-mobile-ios/security)),
and those in the Google Mobile Ads or AppLovin SDKs to their vendors.
