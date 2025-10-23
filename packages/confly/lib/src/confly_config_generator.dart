import 'package:analyzer/dart/element/element2.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:confly_annotation/confly_annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'confly_generator_helper.dart';

/// Checks if you are awesome. Spoiler: you are.
class ConflyConfigGenerator extends GeneratorForAnnotation<ConflyConfig> {
  static final emitter = DartEmitter(
    allocator: Allocator(),
    orderDirectives: true,
    useNullSafetySyntax: true,
  );

  @override
  String generateForAnnotatedElement(
    Element2 element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final buffer = StringBuffer();

    if (element is! ClassElement2) {
      throw InvalidGenerationSourceError(
        'Generator cannot target `${element.name3}`. '
        'Annotation can only be applied to classes.',
        element: element,
      );
    }

    final generatedConflyClass = generateConflyConfig(element);
    buffer.writeln(generatedConflyClass.accept(emitter).toString());

    return buffer.toString();
  }

  Class generateConflyConfig(ClassElement2 element) {
    final codeBuffer = StringBuffer();

    final constructor = element.constructors2.firstWhere((c) => c.name3 == '_');
    final parameters = constructor.formalParameters
        .whereType<FieldFormalParameterElement2>()
        .toList();

    for (final parameter in parameters) {
      codeBuffer.write(
        ConflyGeneratorHelper.generateExtractFieldValue(parameter),
      );
    }

    codeBuffer.writeln();

    codeBuffer.writeln('''
    return Loaded${element.name3}._(${[for (final field in parameters) "${field.name3}: ${field.name3}"].join(', ')});
    ''');

    return Class(
      (builder) => builder
        ..name = 'Loaded${element.name3}'
        ..extend = refer(element.name3!)
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
                  Parameter(
                    (pb) => pb
                      ..name = field.name3!
                      ..named = true
                      ..toSuper = true
                      ..required = true,
                  ),
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
          ),
        ]),
    );
  }
}
