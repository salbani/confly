import 'dart:io';

import 'package:confly_annotation/confly_annotation.dart';

part 'data_test_config.g.dart';

@ConflyRoot(basePath: 'test/data')
class DataTestConfig {
  final String testString;
  final bool testBoolTrue;
  final bool testBoolFalse;
  final int testInt;
  final double testDouble;
  DataTestConfig._({
    required this.testString,
    required this.testBoolTrue,
    required this.testBoolFalse,
    required this.testInt,
    required this.testDouble,
  });
  static DataTestConfigLoader load = _DataTestConfig._load;
}
