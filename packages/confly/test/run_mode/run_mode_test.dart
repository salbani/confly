import 'package:confly_annotation/confly_annotation.dart';
import 'package:test/test.dart';

import 'run_mode_test_config.dart';

void main() {
  group('RunMode', () {
    test('fromString returns correct RunMode for valid inputs', () {
      expect(RunMode.fromString('development'), RunMode.development);
      expect(RunMode.fromString('production'), RunMode.production);
      expect(RunMode.fromString('staging'), RunMode.staging);
      expect(RunMode.fromString('test'), RunMode.test);
    });

    test('fromString throws exception for invalid input', () {
      expect(() => RunMode.fromString('invalid_mode'), throwsException);
    });

    test('toString returns correct string representation', () {
      expect(RunMode.development.toString(), 'development');
      expect(RunMode.production.toString(), 'production');
      expect(RunMode.staging.toString(), 'staging');
      expect(RunMode.test.toString(), 'test');
    });

    test('load development config when no run mode provided', () async {
      final config = await RunModeTestConfig.load();
      expect(config.runMode, 'development');
    });

    test('load correct config when run mode directly provided', () async {
      final configWithoutOverride = await RunModeTestConfig.load();
      final configWithStagingOverride = await RunModeTestConfig.load(
        RunMode.staging,
      );
      final configWithProductionOverride = await RunModeTestConfig.load(
        RunMode.production,
      );
      final configWithTestOverride = await RunModeTestConfig.load(RunMode.test);
      expect(configWithoutOverride.runMode, 'development');
      expect(configWithStagingOverride.runMode, 'staging');
      expect(configWithProductionOverride.runMode, 'production');
      expect(configWithTestOverride.runMode, 'test');
    });
  });
}
