// TODO: Put public facing types in this file.

import '../confly_annotation.dart';

/// Checks if you are awesome. Spoiler: you are.
class ConflyRoot {
  final String? basePath;

  const ConflyRoot({this.basePath});
}

class ConflyConfig {
  const ConflyConfig();
}

class Password {
  final String? name;
  const Password([this.name]);
}

class Environment {
  final String? name;
  const Environment([this.name]);
}

class ConvertValue {
  final Convert convert;
  const ConvertValue(this.convert);
}

class Ignore {
  const Ignore();
}

const conflyRoot = ConflyRoot();

const conflyConfig = ConflyConfig();

const password = Password();

const environment = Environment();

const ignore = Ignore();
