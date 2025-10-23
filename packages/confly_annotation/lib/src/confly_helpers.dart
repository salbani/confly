import 'package:path/path.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'run_mode.dart';

typedef Convert<T> = T Function(String value);

class ConflyHelpers {
  static String _getConfigPath({String? basePath}) {
    return joinAll([basePath ?? '', 'config']);
  }

  static String getConfigFilePath(RunMode runMode, {String? basePath}) {
    return joinAll([_getConfigPath(basePath: basePath), '$runMode.yaml']);
  }

  static String getPasswordsFilePath({String? basePath}) {
    return joinAll([_getConfigPath(basePath: basePath), 'passwords.yaml']);
  }

  static Map loadYaml(String content) {
    return yaml.loadYaml(content) as Map? ?? {};
  }

  static Map<String, String> loadPasswordsFromMap(
    Map passwordConfig,
    RunMode runMode,
  ) {
    var sharedPasswords = _extractPasswords(passwordConfig, 'shared');
    var runModePasswords = _extractPasswords(
      passwordConfig,
      runMode.toString(),
    );

    return {...sharedPasswords, ...runModePasswords};
  }

  static Map<String, String> _extractPasswords(Map data, String key) {
    var extracted = data[key];
    if (extracted is! Map) return {};

    var invalidPasswordKeys = extracted.entries
        .where((entry) => entry.key is! String || entry.value is! String)
        .map((entry) => entry.key);

    if (invalidPasswordKeys.isNotEmpty) {
      throw StateError(
        'Invalid password entries in $key: ${invalidPasswordKeys.join(', ')}',
      );
    }

    return extracted.cast<String, String>();
  }

  // Map<dynamic, dynamic> _extractMapEntry<Env>(
  //   Env serverpodEnv, [
  //   Convert? convert,
  // ]) {
  // var content = serverpodEnv.envVariable;

  // if (content == null) return {};
  // if (convert == null) return {serverpodEnv.configKey: content};

  // try {
  //   return {serverpodEnv.configKey: convert.call(content)};
  // } catch (e) {
  //   throw Exception(
  //     'Invalid value ($content) for ${serverpodEnv.envVariable}.',
  //   );
  // }
  // }
}

class ConflyConverters {
  static bool toBool(String value) {
    final lowerValue = value.toLowerCase();
    if (lowerValue == 'true' || lowerValue == '1') {
      return true;
    } else if (lowerValue == 'false' || lowerValue == '0') {
      return false;
    } else {
      throw Exception('Invalid boolean value: $value');
    }
  }

  static int toInt(String value) {
    return int.parse(value);
  }

  static double toDouble(String value) {
    return double.parse(value);
  }

  static T convert<T>(dynamic value, {Convert<T>? converter}) {
    if (value == null) {
      if (null is! T) {
        throw FormatException(
          'Null value cannot be converted to non-nullable type $T.',
        );
      }
      return null as T;
    }
    value = value.toString();
    if (converter != null) {
      return converter(value);
    } else if (T == String) {
      return value as T;
    } else if (T == int) {
      return toInt(value) as T;
    } else if (T == bool) {
      return toBool(value) as T;
    } else if (T == double) {
      return toDouble(value) as T;
    } else {
      throw Exception(
        'No converter provided for type $T and no default converter available.',
      );
    }
  }
}
