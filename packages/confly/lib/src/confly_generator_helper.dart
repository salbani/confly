import 'package:analyzer/dart/element/element2.dart';
import 'package:code_builder/code_builder.dart';
import 'package:confly_annotation/confly_annotation.dart';
import 'package:path/path.dart';
import 'package:source_gen/source_gen.dart';

class ConflyGeneratorHelper {
  static String getBasePathFromAnnotation(
    ConstantReader annotation,
    bool isFlutter,
  ) {
    var basePath = annotation.peek('basePath')?.stringValue.trim() ?? '';
    if (basePath.startsWith('/')) {
      basePath = basePath.substring(1);
    }
    if (isFlutter) {
      basePath = joinAll(['assets', basePath]);
    }
    return "'$basePath'";
  }

  static StringBuffer generateExtractFieldValue(
    FieldFormalParameterElement2 parameter,
  ) {
    final codeBuffer = StringBuffer();

    final ignoreAnnotation = const TypeChecker.typeNamed(
      Ignore,
    ).firstAnnotationOfExact(parameter.field2!);
    final passwordAnnotation = const TypeChecker.typeNamed(
      Password,
    ).firstAnnotationOfExact(parameter.field2!);
    final convertAnnotation = const TypeChecker.typeNamed(
      ConvertValue,
    ).firstAnnotationOfExact(parameter.field2!);

    if (ignoreAnnotation != null) return codeBuffer;

    final fieldName = parameter.name3!;
    final fieldType = parameter.type;
    final convertFn = convertAnnotation
        ?.getField('convert')!
        .toFunctionValue2()!;

    if (convertFn != null && convertFn.returnType != fieldType) {
      throw InvalidGenerationSourceError(
        'The convert function `${convertFn.name3}` for field `$fieldName` must return type `$fieldType`.',
        element: parameter,
      );
    }

    final convertFnName = convertFn != null
        ? '${convertFn.enclosingElement2?.name3?.isNotEmpty == true ? '${convertFn.enclosingElement2?.name3}.' : ''}${convertFn.name3}'
        : 'ConflyConverters.convert<$fieldType>';
    codeBuffer.writeln(
      "final $fieldName = $convertFnName(_envMap['$fieldName'] ?? ${passwordAnnotation != null ? 'passwords' : 'config'}['$fieldName']);",
    );
    return codeBuffer;
  }

  static StringBuffer generateExtractSubConfigValue(
    FormalParameterElement field,
  ) {
    final codeBuffer = StringBuffer();

    final fieldName = field.name3!;
    final fieldType = field.type.element3?.name3;

    codeBuffer.writeln('''
    final ${fieldName}Config = config['$fieldName'] as Map? ?? {};
    final $fieldName = Loaded$fieldType(config: ${fieldName}Config, passwords: passwords);

    ''');
    return codeBuffer;
  }

  static Field generateEnvMapField(
    ClassElement2 element,
    Iterable<FieldFormalParameterElement2> parameters,
  ) {
    return Field(
      (b) => b
        ..modifier = FieldModifier.constant
        ..static = true
        ..name = '_envMap'
        ..type = refer('Map<String, String?>')
        ..assignment = literalMap({
          for (final p in parameters)
            ...() {
              final environmentAnnotation = const TypeChecker.typeNamed(
                Environment,
              ).firstAnnotationOfExact(p.field2!);

              final envKey =
                  environmentAnnotation?.getField('name')?.toStringValue() ??
                  '${element.name3!.decapitalize()}${p.name3!.capitalize()}'
                      .asEnvKey;
              return {
                p.name3!: Code(
                  "bool.hasEnvironment('$envKey') "
                  "? String.fromEnvironment('$envKey') : null",
                ),
              };
            }(),
        }).code,
    );
  }

  static Method generateToStringMethod(
    ClassElement2 element,
    Iterable<FieldFormalParameterElement2> parameters,
  ) {
    final codeBuffer = StringBuffer();

    codeBuffer.writeln("var str = '';");
    for (final p in parameters) {
      final isConfig = const TypeChecker.typeNamed(
        ConflyConfig,
      ).hasAnnotationOfExact(p.type.element3!);
      if (isConfig) {
        codeBuffer.writeln(
          "str += '${p.name3!.separate()}\\n\${${p.name3}.toString().split(\"\\n\").map((s) => \"\\t\$s\").join(\"\\n\")}\\n';",
        );
      } else {
        codeBuffer.writeln(
          "str += '${p.name3!.separate()}: \${${p.name3}.toString()}\\n';",
        );
      }
    }
    codeBuffer.writeln('return str;');

    return Method(
      (b) => b
        ..name = 'toString'
        ..returns = refer('String')
        ..annotations.add(refer('override'))
        ..body = Code(codeBuffer.toString()),
    );
  }
}

extension on String {
  String get asEnvKey => replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)}',
  ).toUpperCase();

  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String decapitalize() {
    if (isEmpty) return this;
    return this[0].toLowerCase() + substring(1);
  }

  String separate() {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => ' ${match.group(0)}',
    ).toLowerCase().trim();
  }
}
