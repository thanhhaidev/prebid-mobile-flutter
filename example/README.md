# Prebid Mobile Flutter — Example App

A comprehensive demo app showcasing all ad formats supported by the `prebid_mobile_flutter` plugin using **Prebid In-App Rendering**.

## Features

| Feature | Description |
|---|---|
| **6 Ad Formats** | Banner, Video Outstream, Interstitial, Rewarded, Native, Multiformat |
| **36 Test Cases** | All In-App config IDs from Prebid Android demo |
| **MRAID 2.0/3.0** | Expand, Resize, Fullscreen, Viewability Compliance |
| **Settings Persistence** | Server URL, Account ID, privacy toggles saved via SharedPreferences |
| **Dark Mode** | Toggle in Settings, persisted across restarts |
| **Privacy Controls** | GDPR, COPPA, consent string configuration |
| **User Targeting** | Keywords, app ext data, global ORTB config |
| **Event Logging** | Real-time log viewer with timestamped, color-coded entries |
| **Ad Load Timing** | Stopwatch tracks load duration in milliseconds |
| **Copy to Clipboard** | Tap to copy Config ID or Stored Response |
| **About Page** | SDK version, platform info, feature list |

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.11.0
- Android SDK (for Android builds)
- Xcode (for iOS builds)

### Run the Example

```bash
cd example
flutter pub get
flutter run
```

### Build APK

```bash
cd example
flutter build apk --debug
```

## App Structure

```
example/lib/
├── main.dart                          # App entry + SDK init + dark mode
├── data/
│   └── test_case_registry.dart        # 36 In-App test cases
├── models/
│   ├── demo_ad_format.dart            # 10-variant enum
│   └── test_case.dart                 # TestCase model
├── pages/
│   ├── examples_page.dart             # Main list + format filter + search
│   ├── settings_page.dart             # PBS config + privacy + dark mode
│   ├── targeting_data_page.dart       # User/App keywords + ext data + ORTB
│   ├── about_page.dart                # SDK info + platform + links
│   └── detail/
│       ├── banner_detail_page.dart    # Display + Video banner
│       ├── interstitial_detail_page.dart
│       ├── rewarded_detail_page.dart  
│       ├── native_detail_page.dart    
│       ├── video_detail_page.dart     # In-stream video
│       └── multiformat_detail_page.dart
├── utils/
│   ├── app_settings.dart              # SharedPreferences persistence
│   └── logger.dart                    # PrebidDemoLogger singleton
└── widgets/
    ├── action_button.dart             # Styled action button
    ├── config_info_panel.dart         # Config display + copy + load time
    ├── event_counter.dart             # EventTracker + counter list
    ├── log_viewer_panel.dart          # Expandable log viewer
    └── native_ad_card.dart            # Native ad renderer
```

## Configuration

The app uses Prebid's test server by default:

| Setting | Default Value |
|---|---|
| PBS Server URL | `https://prebid-server-test-j.prebid.org/openrtb2/auction` |
| Account ID | `0689a263-318d-448b-a3d4-b02e8a709d9d` |

These can be changed in **Settings** and are persisted across app restarts.

## Test Cases

All 36 test cases use Prebid's stored auction responses for reliable testing:

- **Banner**: 320x50, 300x250, 728x90, Multisize
- **Video Outstream**: Standard, With End Card
- **Display Interstitial**: 320x480
- **Video Interstitial**: Standard, End Card, Deeplink+, SkipOffset, MRAID End Card, Vertical
- **Display Rewarded**: Default, Time-based, Event-based
- **Video Rewarded**: 8 variants (with/without end card, different reward triggers)
- **MRAID**: Expand (1/2 part), Resize, Fullscreen, Video, Negative Test, Viewability, Load+Events
- **Native**: Standard, Links
- **Multiformat**: Banner + Video + Native

## License

Apache License 2.0 — see [LICENSE](../LICENSE) for details.
