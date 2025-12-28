enum RunMode {
  development,
  production,
  staging,
  test;

  factory RunMode.fromString(String value) {
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
