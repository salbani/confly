import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:confly_annotation/confly_annotation.dart';
import 'package:source_gen/source_gen.dart';
import 'package:yaml/yaml.dart';

import 'confly_generator_helper.dart';

/// Checks if you are awesome. Spoiler: you are.
class ConflyRootGenerator extends GeneratorForAnnotation<ConflyRoot> {
  static final emitter = DartEmitter(
    allocator: Allocator(),
    orderDirectives: true,
    useNullSafetySyntax: true,
  );

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final isFlutter = await isFlutterPackage(buildStep);
    final buffer = StringBuffer();

    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Generator cannot target `${element.name}`. '
        'Annotation can only be applied to classes.',
        element: element,
      );
    }

    buffer.writeln(
      TypeDef(
        (builder) => builder
          ..name = '${element.name}Loader'
          ..definition = FunctionType(
            (b) => b
              ..returnType = refer('Future<${element.name}>')
              ..optionalParameters.add(refer('RunMode? runMode')),
          ),
      ).accept(emitter).toString(),
    );

    final generatedConflyClass = generateConflyRootClass(
      element,
      annotation,
      isFlutter,
    );
    buffer.writeln(generatedConflyClass.accept(emitter).toString());

    return buffer.toString();
  }

  Future<bool> isFlutterPackage(BuildStep buildStep) async {
    final pubspecId = AssetId(buildStep.inputId.package, 'pubspec.yaml');
    final pubspec = await buildStep.readAsString(pubspecId);
    final yaml = loadYaml(pubspec);
    return yaml['flutter'] != null;
  }

  Class generateConflyRootClass(
    ClassElement element,
    ConstantReader annotation,
    bool isFlutter,
  ) {
    final generatedClassName = '_${element.name}';
    final constructor = element.constructors.firstWhereOrNull(
      (c) => c.name == '_',
    );

    if (constructor == null) {
      throw InvalidGenerationSourceError(
        'The class `${element.name}` must have a private unnamed constructor.',
        element: element,
      );
    }

    final parameters = constructor.formalParameters
        .whereType<FieldFormalParameterElement>();
    final (match: subConfigParameters, rest: configParameters) = parameters
        .partition(
          (field) => TypeChecker.typeNamed(
            ConflyConfig,
          ).hasAnnotationOfExact(field.type.element!),
        );

    return Class(
      (builder) => builder
        ..name = generatedClassName
        ..extend = refer(element.name!)
        ..fields.add(
          ConflyGeneratorHelper.generateEnvMapField(element, configParameters),
        )
        ..constructors.addAll([
          generateConflyWildcardConstructor(parameters),
          generateConflyFactoryConstructor(
            generatedClassName,
            configParameters,
            subConfigParameters,
          ),
        ])
        ..methods.addAll([
          generateConflyLoadMethod(generatedClassName, element, isFlutter),
          generateGetConfigMethod(annotation, isFlutter),
          generateGetPasswordsMethod(annotation, isFlutter),
          ConflyGeneratorHelper.generateToStringMethod(element, [
            ...configParameters,
            ...subConfigParameters,
          ]),
        ]),
    );
  }

  Constructor generateConflyWildcardConstructor(
    Iterable<FieldFormalParameterElement> parameters,
  ) {
    return Constructor(
      (b) => b
        ..name = '_'
        ..optionalParameters.addAll([
          for (final parameter in parameters)
            Parameter(
              (builder) => builder
                ..name = parameter.name!
                ..named = true
                ..toSuper = true
                ..required = true,
            ),
        ])
        ..initializers.add(Code('super._()')),
    );
  }

  Constructor generateConflyFactoryConstructor(
    String generatedClassName,
    Iterable<FieldFormalParameterElement> configParameters,
    Iterable<FieldFormalParameterElement> subConfigParameters,
  ) {
    return Constructor(
      (b) => b
        ..factory = true
        ..optionalParameters.addAll([
          Parameter(
            (pb) => pb
              ..name = 'config'
              ..type = refer('Map')
              ..required = true
              ..named = true,
          ),
          Parameter(
            (pb) => pb
              ..name = 'passwords'
              ..type = refer('Map')
              ..required = true
              ..named = true,
          ),
        ])
        ..body = Code('''
        ${configParameters.map((p) => ConflyGeneratorHelper.generateExtractFieldValue(p).toString()).join('\n')}
        ${subConfigParameters.map((p) => ConflyGeneratorHelper.generateExtractSubConfigValue(p).toString()).join('\n')}
        return $generatedClassName._(${[
          for (final field in [...configParameters, ...subConfigParameters]) "${field.name}: ${field.name}",
        ].join(', ')});
        '''),
    );
  }

  Method generateConflyLoadMethod(
    String generatedClassName,
    ClassElement element,
    bool isFlutter,
  ) {
    final codeBuffer = StringBuffer();

    codeBuffer.writeln('''
    runMode ??= RunMode.fromEnvironment() ?? (${isFlutter ? 'kReleaseMode ? RunMode.production : ' : ''}RunMode.development);
    final config = await _getConfig(runMode);
    final passwords = await _getPasswords(runMode);
    return $generatedClassName(config: config, passwords: passwords);
    ''');

    return Method(
      (builder) => builder
        ..static = true
        ..name = '_load'
        ..optionalParameters.addAll([
          Parameter(
            (b) => b
              ..type = refer('RunMode?')
              ..name = 'runMode',
          ),
        ])
        ..returns = refer('Future<${element.name!}>')
        ..modifier = MethodModifier.async
        ..body = Code(codeBuffer.toString()),
    );
  }

  Method generateGetConfigMethod(ConstantReader annotation, bool isFlutter) {
    final codeBuffer = StringBuffer();
    final basePath = ConflyGeneratorHelper.getBasePathFromAnnotation(
      annotation,
      isFlutter,
    );

    if (isFlutter) {
      codeBuffer.writeln('''
      final configPath = ConflyHelpers.getConfigFilePath(runMode, basePath: $basePath);
      final configString = await rootBundle.loadString(configPath);
      ''');
    } else {
      codeBuffer.writeln('''
      final configPath = ConflyHelpers.getConfigFilePath(runMode, basePath: $basePath);
      final configFile = File(configPath);
      final configString = await configFile.readAsString();
      ''');
    }

    codeBuffer.writeln('return ConflyHelpers.loadYaml(configString);');

    return Method(
      (builder) => builder
        ..name = '_getConfig'
        ..static = true
        ..modifier = MethodModifier.async
        ..requiredParameters.addAll([
          Parameter(
            (b) => b
              ..type = refer('RunMode')
              ..name = 'runMode',
          ),
        ])
        ..returns = refer('Future<Map>')
        ..body = Code(codeBuffer.toString()),
    );
  }

  Method generateGetPasswordsMethod(ConstantReader annotation, bool isFlutter) {
    final codeBuffer = StringBuffer();
    final basePath = ConflyGeneratorHelper.getBasePathFromAnnotation(
      annotation,
      isFlutter,
    );

    if (isFlutter) {
      codeBuffer.writeln('''
      final passwordsPath = ConflyHelpers.getPasswordsFilePath(basePath: $basePath);
      final passwordsString = await rootBundle.loadString(passwordsPath);
      ''');
    } else {
      codeBuffer.writeln('''
      final passwordsPath = ConflyHelpers.getPasswordsFilePath(basePath: $basePath);
      final passwordsFile = File(passwordsPath);
      final passwordsString = await passwordsFile.exists() ? await passwordsFile.readAsString() : '';
      ''');
    }

    codeBuffer.writeln('''
    final passwordsMap = ConflyHelpers.loadYaml(passwordsString);
    return ConflyHelpers.loadPasswordsFromMap(passwordsMap, runMode);
    ''');

    return Method(
      (builder) => builder
        ..name = '_getPasswords'
        ..modifier = MethodModifier.async
        ..static = true
        ..returns = refer('Future<Map<String, String>>')
        ..requiredParameters.addAll([
          Parameter(
            (b) => b
              ..type = refer('RunMode')
              ..name = 'runMode',
          ),
        ])
        ..body = Code(codeBuffer.toString()),
    );
  }
}

extension Partition<T> on Iterable<T> {
  ({List<T> match, List<T> rest}) partition(bool Function(T) test) {
    final match = <T>[];
    final rest = <T>[];
    for (final e in this) {
      (test(e) ? match : rest).add(e);
    }
    return (match: match, rest: rest);
  }
}
