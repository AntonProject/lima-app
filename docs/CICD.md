# CI/CD — Store Releases

Pushing to `main` (or running the **Release** workflow manually) builds the app
and uploads it to **Google Play** (internal track) and **TestFlight**.

- Workflow: [.github/workflows/release.yml](../.github/workflows/release.yml)
- Android upload lane: [android/fastlane/Fastfile](../android/fastlane/Fastfile)
- iOS upload lane: [ios/fastlane/Fastfile](../ios/fastlane/Fastfile)
- Version/build number come from `pubspec.yaml` (`version: x.y.z+N`). **Bump it
  before each release** — Play/TestFlight reject a build number that already
  exists.

The workflow skips doc-only pushes (`**.md`, `docs/**`).

## Required GitHub Secrets

Add these under **Settings → Secrets and variables → Actions → New repository
secret**. Never commit any of these values; the workflow writes them to disk at
build time and the files are gitignored.

### Android (Google Play)

| Secret | What it is |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The upload keystore (`.jks`), base64-encoded: `base64 -i upload-keystore.jks \| pbcopy` |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Full JSON of the Google Play service account (paste the file contents) |

The service account needs the **Release to testing tracks** permission in the
Play Console (Users and permissions).

### iOS (TestFlight)

| Secret | What it is |
| --- | --- |
| `IOS_DIST_CERT_P12_BASE64` | Apple **Distribution** certificate exported as `.p12`, base64-encoded |
| `IOS_DIST_CERT_PASSWORD` | Password set when exporting the `.p12` |
| `IOS_PROVISION_PROFILE_BASE64` | App Store provisioning profile for `uz.lima.lima` (`.mobileprovision`), base64-encoded |
| `ASC_API_KEY_P8_BASE64` | App Store Connect API key (`AuthKey_XXXX.p8`), base64-encoded |
| `ASC_KEY_ID` | The API key's Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |

Create the API key in **App Store Connect → Users and Access → Integrations →
App Store Connect API** with the **App Manager** role.

To base64-encode a file on macOS:

```sh
base64 -i AuthKey_XXXXXX.p8 | pbcopy   # then paste into the secret
```

## Notes

- Team ID `5N9G35WULY`, bundle id / applicationId `uz.lima.lima` (both platforms).
- iOS export uses [ios/ExportOptions.plist](../ios/ExportOptions.plist)
  (`method: app-store`).
- Android track defaults to `internal`; change `track:internal` in the workflow
  to `beta`/`production` when you want a wider rollout.
- Local release builds still need `android/key.properties` + the keystore (see
  [android/app/build.gradle.kts](../android/app/build.gradle.kts)); these are
  gitignored and recreated from secrets in CI.
