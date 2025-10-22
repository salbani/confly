import 'package:test/test.dart';

import 'data_test_config.dart';

void main() {
  group('data', () {
    test('data types load correctly', () async {
      final config = await DataTestConfig.load();
      expect(config.testString, 'development');
      expect(config.testBoolTrue, true);
      expect(config.testBoolFalse, false);
      expect(config.testInt, 123);
      expect(config.testDouble, 12.3);
    });
  });
}
