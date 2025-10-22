import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:confly/src/confly_generator_helper.dart';
import 'package:confly_annotation/confly_annotation.dart';
import 'package:source_gen/source_gen.dart';

/// Checks if you are awesome. Spoiler: you are.
class ConflyConfigGenerator extends GeneratorForAnnotation<ConflyConfig> {
  static final emitter = DartEmitter(
    allocator: Allocator(),
    orderDirectives: true,
    useNullSafetySyntax: true,
  );

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final buffer = StringBuffer();

    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'Generator cannot target `${element.name}`. '
        'Annotation can only be applied to classes.',
        element: element,
      );
    }

    final generatedConflyClass = generateConflyConfig(element);
    buffer.writeln(generatedConflyClass.accept(emitter).toString());

    return buffer.toString();
  }

  Class generateConflyConfig(ClassElement element) {
    final codeBuffer = StringBuffer();

    final constructor = element.constructors.firstWhere((c) => c.name == '_');
    final parameters = constructor.formalParameters
        .whereType<FieldFormalParameterElement>()
        .toList();

    for (final parameter in parameters) {
      codeBuffer.write(
        ConflyGeneratorHelper.generateExtractFieldValue(parameter),
      );
    }

    codeBuffer.writeln();

    codeBuffer.writeln('''
    return Loaded${element.name}._(${[
      for (final field in parameters) "${field.name}: ${field.name}"
    ].join(', ')});
    ''');

    return Class(
      (builder) => builder
        ..name = 'Loaded${element.name}'
        ..extend = refer(element.name!)
        ..fields.add(
          ConflyGeneratorHelper.generateEnvMapField(element, parameters),
        )
        ..methods.addAll([
          ConflyGeneratorHelper.generateToStringMethod(element, parameters),
        ])
        ..constructors.addAll([
          Constructor(
            (b) => b
              ..name = '_'
              ..optionalParameters.addAll([
                for (final field in parameters)
                  Parameter((pb) => pb
                    ..name = field.name!
                    ..named = true
                    ..toSuper = true
                    ..required = true),
              ])
              ..initializers.add(Code('super._()')),
          ),
          Constructor(
            (b) => b
              ..factory = true
              ..optionalParameters.addAll([
                Parameter(
                  (pb) => pb
                    ..name = 'config'
                    ..type = refer('Map')
                    ..named = true
                    ..required = true,
                ),
                Parameter(
                  (pb) => pb
                    ..name = 'passwords'
                    ..type = refer('Map')
                    ..named = true
                    ..required = true,
                ),
              ])
              ..body = Code(codeBuffer.toString()),
          )
        ]),
    );
  }
}
