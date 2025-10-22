# confly

Type-safe, hierarchical application configuration for Dart and Flutter with
first-class support for multiple run modes and secret management.

## Overview

confly provides a single, type-safe way to define and load application
configuration. You declare your configuration as Dart classes and
confly generates fast, ergonomic loaders that read YAML files per
run mode (`development`, `staging`, and `production`).

The goals are:

- keep configuration declarative and type-checked at compile time
- keep the code minimal, boilerplate free and maintainable through code generation
- support multiple run modes with simple file overrides
- allow environment variable and secret overrides for CI/CD and runtime
- produce generated code that is easy to use in both Dart and Flutter
  projects

*shutout: The functionality is inspired by serverpod and freezed/json_serializable.*

## Quick start

1. Add package dependencies to your `pubspec.yaml`:

To use confly, you will need your typical build_runner/code-generator setup.
First, install build_runner and confly by adding them to your pubspec.yaml file:

For a Flutter project:

```bash
flutter pub add \
  dev:build_runner \
  confly_annotation \
  dev:confly
```

For a Dart project:

```bash
dart pub add \
  dev:build_runner \
  confly_annotation \
  dev:confly
```

This installs three packages:

- build_runner, the tool to run code-generators
- confly, the code generator
- confly_annotation, a package containing annotations and helper functions for confly.

1. Define your configuration classes and annotate them for generation:

```dart
// IMPORTANT (ONLY) FOR DART PROJECTS
import 'dart:io';

import 'package:confly_annotation/confly_annotation.dart';
// IMPORTANT (ONLY) FOR FLUTTER PROJECTS
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

part 'my_config.g.dart';

@conflyRoot
class MyConfig {
  final String apiUrl;
  final SubConfig subConfig;

  const MyConfig._({required this.apiUrl, required this.subConfig});

  // generated loader assigned here
  static MyConfigLoader load = _MyConfig._load;
}

@conflyConfig
class SubConfig {
  final String featureFlag;
  const SubConfig._({required this.featureFlag});
}
```

1. Provide YAML files for each run mode (example:
  `config/development.yaml`):

```yaml
apiUrl: "https://dev.api.com"
subConfig:
  featureFlag: "enabled"
```

1. Generate code and load the configuration:

```bash
dart run build_runner build

// usage at runtime
final config = await MyConfig.load();
print(config.apiUrl);
```

## Annotations

### Class annotations

confly provides a few class-level annotations that control how your
config classes are treated by the generator and runtime loader.

- `@conflyRoot` — Mark the root configuration class. This class represents
  the top-level configuration object and is where the generated loader is
  bound. A root class exposes the fields (and
  nested sub-configs) that make up your application configuration.

- `@conflyConfig` — Mark a nested or standalone config class. Use this on
  types that are referenced by the root config and should be generated as
  part of the overall configuration tree.

Examples and loader naming

The generator produces a private implementation class (`_AppConfig` in the
example below) and a generated loader function that is typically assigned to
a static field on the root class (for example `AppConfigLoader load =
_AppConfig._load`). This gives you a simple runtime entry point to load the
configuration.

```dart
@conflyRoot
class AppConfig {
  final DatabaseConfig database;
  const AppConfig._({required this.database});

  // the generated loader is assigned here; call `await AppConfig.load()` at runtime
  static AppConfigLoader load = _AppConfig._load;
}

@conflyConfig
class DatabaseConfig {
  final String host;
  final int port;
  const DatabaseConfig._({required this.host, required this.port});
}
```

### Variable annotations

- `@Environment('ENV_VAR')` — Set a custom environment
  variable name. Useful to make the name explicit or to match existing
  environment variable conventions in your organization. If not provided,
  confly derives the environment variable name from the field name using
  uppercase snake case (for example, `apiUrl` in the config class `ApiConfig`
  becomes `API_CONFIG_API_URL`).

- `@password` — Mark a field as a secret. Passwords (and other secrets)
  are treated differently from ordinary config values: they are typically
  provided via the `config/passwords.yaml` and are not committed to VCS.
  See more [below](#passwords).

- `@ignore` — Exclude a field from generation and loading. Use this for
  transient or derived properties that should not be part of the persisted
  configuration.

- `@ConvertValue` — Apply a custom converter to a value when reading from
  YAML or environment variables. This is useful for parsing complex types or
  applying validation/coercion rules.

Examples:

```dart
@conflyConfig
class ApiConfig {
  @Environment('API_URL')
  final String url;

  @password
  @Environment('API_KEY')
  final String apiKey;

  @ignore
  String someDifferentlyUsedVariable;

  @ConvertValue(someEnumConverter)
  final SomeEnum enumValue;

  const ApiConfig._({required this.url, required this.apiKey});
}
```

In the example above, `url` will be read from the `API_URL` environment
variable if present. `apiKey` is a password field and is explicitly mapped to
the environment variable `MYAPP_API_KEY` using `@Environment`.
The `someDifferentlyUsedVariable` field is ignored by the generator and
will not be part of the loaded configuration. The `enumValue` field uses a
custom converter function `someEnumConverter` to parse its value.

## Run modes

confly uses a RunMode enum to select which YAML file to load from `config/`.
Available modes are: `development`, `staging`, `production`, and `test`.

Files are resolved as `config/<run_mode>.yaml`. You do not need to provide
all files — however, if you attempt to load a run mode whose file is missing
the loader will fail.

Selection precedence (highest → lowest):

1. Explicit RunMode passed to the generated loader.
2. Compile-time value from the `RUN_MODE` define (used via
   `--dart-define=RUN_MODE=...`). The generated loader defaults to
   `development` when no value is provided.
3. Default to `development` mode, except running in Flutter release mode
   (where it defaults to `production`).

Examples

```dart
// pass the enum directly
final myConfig = await MyConfig.load(RunMode.production);
```

```bash
# compile/run with a compile-time define
dart run --dart-define=RUN_MODE=staging
```

## Config file structure

```text
package or assets directory (depending on flutter or dart project)/
├─ config/
│  ├─ <run_mode>.yaml # needed run modes, e.g. development.yaml, production.yaml
│  └─ passwords.yaml   # only if needed and not committed; contains secrets
└─ ....
```

### Dart vs Flutter projects

The configuration placement differs slightly between Dart-only and
Flutter projects because of typical project layouts and asset handling:

#### Dart server or CLI projects

Place your `config/` directory at the project root (next to
`pubspec.yaml`). Loaders will read files directly from the filesystem.

#### Flutter apps

For Flutter, include your YAML files under a top-level `config/`
directory and add them as assets in `pubspec.yaml`, or load them
from an external source at runtime (recommended for secrets).

Example `pubspec.yaml` asset entry:

```yaml
flutter:
  assets:
    - config/development.yaml
    - config/production.yaml
```

When using assets, the app must load the YAML via Flutter's
asset bundle API (the confly loader supports this usage pattern).

In short: put `config/` at your project root for both project types, but for
Flutter you will typically include run mode files as assets or use a
remote config/secrets provider for production deployments.

## Passwords

Important: Always keep `passwords.yaml` and other secret files out of
version control. Use a secrets manager or CI/CD secret storage instead.

How confly handles passwords and secrets:

- Annotate sensitive fields with `@password` in your config class.
- By default, confly prefers secrets from (highest to lowest precedence):
  1. Environment variables
  2. `config/passwords.yaml`
  3. The environment-specific YAML file (for non-sensitive defaults)

Sample usage:

```dart
@conflyConfig
class DatabaseConfig {
  final String host;
  final int port;
  @password
  final String passwordField;
  @password
  final String sharedPasswordField;

  const DatabaseConfig._({required this.host, required this.port, required this.password});
}
```

Example `passwords.yaml` (structure used by the example project):

```yaml
shared:
  sharedPasswordField: 'shared_password'
development:
  passwordField: 'development_password'
staging:
  passwordField: 'staging_password'
production:
  passwordField: 'production_password'
```

- Prefer environment variables or a dedicated secret manager to generate the
  `passwords.yaml` in production. Keep `passwords.yaml` local and out of Git.
- Use clear, consistent environment variable names to make CI integration
  straightforward. confly supports custom environment variable names via
  `@Environment('ENV_NAME')` on fields.
- If a secret appears in multiple sources, the precedence order above
  determines which value is used at runtime.

## Example

The `example/` directory contains a minimal runnable demo illustrating
config class definitions, run mode YAML files, and generated code usage.

## License

MIT
