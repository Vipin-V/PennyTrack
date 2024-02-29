# ![Flow logo](logo@32.png) Flow

[![Flow's GitHub repo](https://img.shields.io/badge/GitHub-flow--mn/flow-f5ccff?logo=github&logoColor=white&style=for-the-badge)](https://github.com/flow-mn/flow)&nbsp;
[![Join Flow Discord server](https://img.shields.io/badge/Discord-Flow-f5ccff?logo=discord&logoColor=white&style=for-the-badge)](https://discord.gg/Ndh9VDeZa4)
[![Support on Ko-fi](https://img.shields.io/badge/kofi-sadespresso-f5ccff?logo=ko-fi&logoColor=white&style=for-the-badge&label=Ko-fi)](https://ko-fi.com/sadespresso)

## Try test builds

[![Join Play Store Open Testing](https://img.shields.io/badge/Google_Play-open_testing-f5ccff?logo=google-play&logoColor=white&style=for-the-badge)](https://play.google.com/store/apps/details?id=mn.flow.flow)
[![Join TestFlight group](https://img.shields.io/badge/TestFlight-beta_testing-f5ccff?logo=appstore&logoColor=white&style=for-the-badge)](https://testflight.apple.com/join/NH4ifijS)
[![See Codemagic builds](https://img.shields.io/badge/CodeMagic-see_builds-f5ccff?logo=codemagic&logoColor=white&style=for-the-badge)](https://codemagic.io/apps/65950ed30591c25df05b5613/65950ed30591c25df05b5612/latest_build)

## Preface

Flow is a free, open-source, cross-platform personal finance tracking app.

[**Will be**](#release-date) available on Android, iOS, and more[^1]

### Features

* Multiple accounts
* Multiple currencies
* Fully-offline
* Full export/backup
  * JSON for backup
  * CSV for external software use (i.e., Google Sheets)

## Release date

Flow is currently in development, and is planned to release beta builds in
early March.

You can try alpha builds right now from the badges at the top of the page.
JSON backups are guaranteed to be supported by the stable release.

## Supported platforms

* Android
* iOS
* and more[^1]

## Development

Please read [Contribuition guide](./CONTRIBUTING.md) before contributing.

### Prerequisites

* [Flutter](https://flutter.dev/) (stable)

Other:

* JDK 17 if you're gonna build for Android
* [XCode](https://developer.apple.com/xcode/) if you're gonna build for iOS/macOS
* To run tests on your machine, see [Testing](#testing)

Building for Windows, Linux-based requires the same dependencies as Flutter.
Read more on <https://docs.flutter.dev/platform-integration>

### Running

`flutter run`

See more on <https://flutter.dev/>

### Testing

Generally, tests will be run by GitHub actions. But if you plan to run tests on
your machine, ensure you've installed ObjectBox dynamic libraries.

Install ObjectBox dynamic libraries[^2]:

`bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)`

Testing:

`flutter test`

[^1]: Will be available on macOS, Windows, and Linux-based systems, but no plan
to enhance the UI for desktop experience for now.

[^2]: Please double-check from the official website, may be outdated. Visit
<https://docs.objectbox.io/getting-started#add-objectbox-to-your-project>
(make sure to choose Flutter to see the script).
