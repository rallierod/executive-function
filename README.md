# executive_function

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## iOS TestFlight CI

This repo includes GitHub Actions workflow `.github/workflows/ios-testflight.yml` to build and upload a native iOS `.ipa` to TestFlight.

### 1) Required Apple setup

1. In Apple Developer, create an App ID and App Store app for your real bundle id.
2. In Xcode project settings, replace the default bundle id `com.example.executiveFunction` with your real bundle id.
3. Create an `Apple Distribution` certificate (`.p12`) and an App Store provisioning profile for that bundle id.
4. In App Store Connect, create an API key (Issuer ID, Key ID, private key `.p8`).

### 2) GitHub repository variables

Add these in `Settings > Secrets and variables > Actions > Variables`:

- `IOS_BUNDLE_ID` (example: `com.yourcompany.executivefunction`)
- `IOS_PROVISIONING_PROFILE_NAME` (exact provisioning profile name in Apple Developer)
- `IOS_TEAM_ID` (10-character Apple Team ID)

### 3) GitHub repository secrets

Add these in `Settings > Secrets and variables > Actions > Secrets`:

- `IOS_DIST_CERT_P12_BASE64` (base64 of distribution `.p12`)
- `IOS_DIST_CERT_PASSWORD` (password used when exporting `.p12`)
- `IOS_PROVISION_PROFILE_BASE64` (base64 of `.mobileprovision`)
- `KEYCHAIN_PASSWORD` (any strong random string for CI keychain)
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY` (full `.p8` content, including BEGIN/END lines)

### 4) Run the workflow

1. Go to `Actions > iOS TestFlight > Run workflow` for manual upload.
2. Or push a tag like `ios-v1.0.0` to trigger automatic upload.

The workflow also uploads the built `.ipa` as an artifact in GitHub Actions.
