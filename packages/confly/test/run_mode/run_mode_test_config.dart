import 'dart:io';

import 'package:confly_annotation/confly_annotation.dart';

part 'run_mode_test_config.g.dart';

@ConflyRoot(basePath: 'test/run_mode')
class RunModeTestConfig {
  final String runMode;
  RunModeTestConfig._({required this.runMode});
  static RunModeTestConfigLoader load = _RunModeTestConfig._load;
}
