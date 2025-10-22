/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

import 'package:build/build.dart';
import 'package:confly/src/confly_config_generator.dart';
import 'package:source_gen/source_gen.dart';

import 'src/confly_root_generator.dart';

Builder conflyGenerator(BuilderOptions options) => SharedPartBuilder(
      [
        ConflyRootGenerator(),
        ConflyConfigGenerator(),
      ],
      'confly',
    );
