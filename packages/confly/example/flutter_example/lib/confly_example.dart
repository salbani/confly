import 'package:confly_annotation/confly_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part 'confly_example.g.dart';

@conflyRoot
class ExampleConfig {
  final String exampleField;
  final SubConfig? subConfig;

  const ExampleConfig._({required this.exampleField, required this.subConfig});

  static ExampleConfigLoader load = _ExampleConfig._load;
}

List<String> customConvert(String value) => value.split('');

@conflyConfig
class SubConfig {
  final String testString;
  final bool testBool;
  final int testInt;
  final double testDouble;
  @ConvertValue(customConvert)
  final List<String> testConvert;
  @Environment('ENV_FIELD')
  final String testFromEnvironment;
  @password
  final String passwordField;
  @password
  final String sharedPasswordField;
  @ignore
  String? ignoreField;

  SubConfig._({
    required this.passwordField,
    required this.sharedPasswordField,
    required this.testString,
    required this.testBool,
    required this.testInt,
    required this.testDouble,
    required this.testConvert,
    required this.testFromEnvironment,
  });
}

void main(List<String> args) async {
  final config = await ExampleConfig.load();
  print(config.toString());
}
