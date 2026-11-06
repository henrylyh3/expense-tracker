# Release workflow

For each completed change to this app:

1. Increase the app version and build number in `pubspec.yaml`. Match the fallback version in `lib/core/app_info.dart`. Keep the Android package ID and release signing key so existing installations can update in place.
2. Run `flutter analyze` and the relevant tests. Finish testing before starting the APK build so both commands can use the build directory safely.
3. Build a signed ARM64 APK with `flutter build apk --release --target-platform android-arm64 --split-per-abi`. Verify the signature, package ID, version code, and architecture. The version code must be higher than that of the previous APK.
4. Copy the APK to `release/expense-tracker-<version>-arm64-release.apk`. Keep earlier APKs and keep the keystore and `android/key.properties` private.
5. Commit the completed changes and the new APK together. Push the commit to GitHub and verify the remote branch contains it. Report the APK path, commit, and test results.
