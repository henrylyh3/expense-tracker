# Testing policy

- Run only tests for the new or changed feature and tests for directly linked behavior that the change can affect.
- Add focused test cases when needed. Keep tests modular so related checks can run independently.
- Do not run the full test suite unless the user explicitly asks. Leave unrelated tests untouched.
- Run `flutter analyze` for code changes. Complete selected tests before starting an APK build.
- Documentation-only changes do not require tests, a version bump, or a new APK.

# Release workflow

For each completed change to this app:

1. Increase the app version and build number in `pubspec.yaml`. Match the fallback version in `lib/core/app_info.dart`. Keep the Android package ID and release signing key so existing installations can update in place.
2. Run `flutter analyze` and only the focused tests required by the testing policy above. Finish testing before starting the APK build so both commands can use the build directory safely. Do not run the full test suite unless explicitly requested.
3. Build a signed ARM64 APK with `flutter build apk --release --target-platform android-arm64 --split-per-abi`. Verify the signature, package ID, version code, and architecture. The version code must be higher than that of the previous APK.
4. Copy the APK to `release/expense-tracker-<version>-arm64-release.apk`. Run `python tool/publish_release.py --prepare` to prepare the matching update manifest. Write release notes in `docs/releases/v<version>.md`. Keep earlier APKs and keep the keystore and `android/key.properties` private.
5. Commit the completed changes and the new APK together. Push the commit to GitHub and verify the remote branch contains it. Report the APK path, commit, and test results.
6. Run `python tool/publish_release.py --notes-file docs/releases/v<version>.md` to publish the signed APK and update manifest to GitHub Releases. Verify the public latest release and both uploaded files/checksums. Do not overwrite a published version or embed GitHub credentials in the app.
