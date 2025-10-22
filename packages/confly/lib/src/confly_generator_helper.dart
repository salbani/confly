import 'package:analyzer/dart/element/element.dart';
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
    FieldFormalParameterElement parameter,
  ) {
    final codeBuffer = StringBuffer();

    final ignoreAnnotation = const TypeChecker.typeNamed(
      Ignore,
    ).firstAnnotationOfExact(parameter.field!);
    final passwordAnnotation = const TypeChecker.typeNamed(
      Password,
    ).firstAnnotationOfExact(parameter.field!);
    final convertAnnotation = const TypeChecker.typeNamed(
      ConvertValue,
    ).firstAnnotationOfExact(parameter.field!);

    if (ignoreAnnotation != null) return codeBuffer;

    final fieldName = parameter.name!;
    final fieldType = parameter.type;
    final convertFn = convertAnnotation
        ?.getField('convert')!
        .toFunctionValue()!;

    if (convertFn != null && convertFn.returnType != fieldType) {
      throw InvalidGenerationSourceError(
        'The convert function `${convertFn.name}` for field `$fieldName` must return type `$fieldType`.',
        element: parameter,
      );
    }

    final convertFnName = convertFn != null
        ? '${convertFn.enclosingElement?.name?.isNotEmpty == true ? '${convertFn.enclosingElement?.name}.' : ''}${convertFn.name}'
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

    final fieldName = field.name!;
    final fieldType = field.type.element?.name;

    codeBuffer.writeln('''
    final ${fieldName}Config = config['$fieldName'] as Map? ?? {};
    final $fieldName = Loaded$fieldType(config: ${fieldName}Config, passwords: passwords);

    ''');
    return codeBuffer;
  }

  static Field generateEnvMapField(
    ClassElement element,
    Iterable<FieldFormalParameterElement> parameters,
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
              ).firstAnnotationOfExact(p.field!);

              final envKey =
                  environmentAnnotation?.getField('name')?.toStringValue() ??
                  '${element.name!.decapitalize()}${p.name!.capitalize()}'
                      .asEnvKey;
              return {
                p.name!: Code(
                  "bool.hasEnvironment('$envKey') "
                  "? String.fromEnvironment('$envKey') : null",
                ),
              };
            }(),
        }).code,
    );
  }

  static Method generateToStringMethod(
    ClassElement element,
    Iterable<FieldFormalParameterElement> parameters,
  ) {
    final codeBuffer = StringBuffer();

    codeBuffer.writeln("var str = '';");
    for (final p in parameters) {
      final isConfig = const TypeChecker.typeNamed(
        ConflyConfig,
      ).hasAnnotationOfExact(p.type.element!);
      if (isConfig) {
        codeBuffer.writeln(
          "str += '${p.name!.separate()}\\n\${${p.name}.toString().split(\"\\n\").map((s) => \"\\t\$s\").join(\"\\n\")}\\n';",
        );
      } else {
        codeBuffer.writeln(
          "str += '${p.name!.separate()}: \${${p.name}.toString()}\\n';",
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
