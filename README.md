# RealNews for iOS 6

A universal RSS and Atom feed reader for **jailbroken iOS 6.x** devices (armv7, e.g. iPad 2, iPhone 4S),
with a second build for **64-bit devices with iOS 14–17** (iPhone X and newer: rootless jailbreaks and TrollStore)
that preserves the classic glossy iOS 6 aesthetic.

Based on the [RealNews concept](https://github.com/OlivierGuinart/RealNews), this reader extracts and exposes **all metadata fields** from the feed output—not just headlines and snippets, but every custom attribute, namespaced tag (`dc:creator`, `content:encoded`, `media:content`, `guid`, `category`), and author-devised metadata.

Because modern feeds and CDNs require TLS 1.2/1.3 with AEAD cipher suites that the legacy iOS 6 networking stack cannot negotiate,
the app embeds its own TLS stack (Mbed TLS) and HTTP client: everything connects directly from your device without any relay server.

## Features

- **All Fields & Metadata Inspector**: Dedicated inspector screen revealing every single XML tag, attribute, and custom metadata field with one-tap copy and link opening.
- **Embedded RealNews Metadata Table**: Articles render responsive HTML with an integrated `<table class="extradata">` for rich feed properties.
- **Universal Interface**:
  - iPad: Full `UISplitViewController` master-detail layout (feeds & article list on left, reader & metadata on right).
  - iPhone: Classic 3-tier navigation stack with fluid transitions.
- **Smart Cache Management**:
  - Image cache with LRU limits, size inspection, and one-tap cache clearing so device storage never clogs.
  - Configurable article retention (7, 14, 30 days, or forever) and maximum item caps per feed.
- **Rich Media & Attachments**: Media thumbnails, podcasts, and enclosures with file size badges and playback options.
- **Search & Filtering**: Real-time search by title, snippet, and author, plus dedicated "All Unread" and "Starred" smart views.
- **Authentic iOS 6 Look**: Glossy navigation bar, blue unread badges, classic linen/pinstripe backgrounds, and skeuomorphic finish.
- **Bilingual**: Full English and Czech (`en.lproj` and `cs.lproj`) localization.

## Download

Get the latest packages from the [Releases](../../releases/latest) page:

| Device | Package |
| --- | --- |
| iOS 6.x, 32-bit (iPad 2, iPhone 4S, …) | `RealNews-<version>.ipa` or `com.samcejko.realnews_<version>_iphoneos-arm.deb` |
| iOS 14–17, 64-bit, rootless jailbreak (palera1n, Dopamine) | `com.samcejko.realnews_<version>_iphoneos-arm64.deb` |
| iOS 14–17, 64-bit, TrollStore | `RealNews-<version>-arm64.ipa` |

## Installing on the device

The easy way: add the repository `http://repo.samcejko.eu/` in Cydia (Sources → Edit → Add), Sileo, Zebra or Installer
and install RealNews from there.

By hand:
1. Cydia: **AppSync Unified** (repo `https://cydia.akemi.ai/`) and **IPA Installer Console** (BigBoss).
2. Copy the `.ipa` to the device and run `ipainstaller -f RealNews.ipa`, or install the `.deb` via `dpkg -i` followed by `uicache`.

On iOS 14–17 (64-bit): with a rootless jailbreak install the `iphoneos-arm64` `.deb` with `dpkg -i`; without a jailbreak open the `-arm64.ipa` in [TrollStore](https://github.com/opa334/TrollStore).

## Building (GitHub Actions)

No Mac needed. Every push and pull request runs `.github/workflows/build.yml` on Ubuntu with Theos and Mbed TLS:

- `ios6-armv7`: iOS 9.3 SDK, deployment target 6.0 → `RealNews-<version>.ipa` and `.deb`.
- `ios14-arm64`: iOS 16.5 SDK, deployment target 14.0 → `RealNews-<version>-arm64.ipa` and `iphoneos-arm64.deb`.

Local PowerShell helpers (Windows):
```powershell
.\tools\gh-push.ps1 -Message "update"    # push via GitHub REST API
.\tools\gh-build.ps1 -Download -Install  # trigger build, fetch packages, install to device
.\tools\make-icon.ps1                    # render glossy iOS 6 icons
```
