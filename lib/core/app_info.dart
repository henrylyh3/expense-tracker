// Informational backup metadata; format/schema versions decide compatibility.
// Release builds may override this with --dart-define=APP_VERSION=<version+build>.
const appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.1.0+1',
);
