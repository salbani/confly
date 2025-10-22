import 'dart:async';

enum RunMode {
  development,
  production,
  staging,
  test;

  static String? _environmentOverride = null;

  static RunMode? fromEnvironment() =>
      bool.hasEnvironment('RUN_MODE') || _environmentOverride != null
      ? fromString(_environmentOverride ?? String.fromEnvironment('RUN_MODE'))
      : null;

  static FutureOr<void> runWithEnvironmentOverride(
    String? override,
    FutureOr<void> Function() body,
  ) {
    _environmentOverride = override;
    try {
      return body();
    } finally {
      _environmentOverride = null;
    }
  }

  static RunMode fromString(String value) {
    switch (value) {
      case 'development':
        return development;
      case 'production':
        return production;
      case 'staging':
        return staging;
      case 'test':
        return test;
      default:
        throw FormatException(
          'Invalid run mode: $value. Must be one of: development, production or staging.',
        );
    }
  }

  @override
  String toString() {
    switch (this) {
      case development:
        return 'development';
      case production:
        return 'production';
      case staging:
        return 'staging';
      case test:
        return 'test';
    }
  }
}
