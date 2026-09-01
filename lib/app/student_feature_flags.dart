/// Build-time switches for canary-only student demos.
abstract final class StudentFeatureFlags {
  static const servicesDemo = bool.fromEnvironment(
    'STUDENT_SERVICES_DEMO',
    defaultValue: false,
  );
  static const storeDemo = bool.fromEnvironment(
    'STUDENT_STORE_DEMO',
    defaultValue: false,
  );
}
