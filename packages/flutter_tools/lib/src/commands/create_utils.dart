// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../android/android.dart' as android_common;
import '../android/android_workflow.dart';
import '../android/gradle_utils.dart' as gradle;
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../convert.dart';
import '../dart/pub.dart';
import '../flutter_project_metadata.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../runner/flutter_command.dart';
import '../template.dart';

/// Mixin contains methods that are shared with `flutter create` commands.
mixin CreateCommandMixin on FlutterCommand {
  /// Throw with exit code 2 if the output directory is invalid.
  void validateOutoutDirectoryArg() {
    if (argResults.rest.isEmpty) {
      throwToolExit('No option specified for the output directory.\n$usage',
          exitCode: 2);
    }

    if (argResults.rest.length > 1) {
      String message = 'Multiple output directories specified.';
      for (final String arg in argResults.rest) {
        if (arg.startsWith('-')) {
          message += '\nTry moving $arg to be immediately following $name';
          break;
        }
      }
      throwToolExit(message, exitCode: 2);
    }
  }

  /// Gets the flutter root directory.
  ///
  /// Throw with exit code 2 if the flutter sdk installed is invalid.
  String getFlutterRoot() {
    if (Cache.flutterRoot == null) {
      throwToolExit(
          'Neither the --flutter-root command line flag nor the FLUTTER_ROOT environment '
          'variable was specified. Unable to find package:flutter.',
          exitCode: 2);
    }
    final String flutterRoot = globals.fs.path.absolute(Cache.flutterRoot);

    final String flutterPackagesDirectory =
        globals.fs.path.join(flutterRoot, 'packages');
    final String flutterPackagePath =
        globals.fs.path.join(flutterPackagesDirectory, 'flutter');
    if (!globals.fs
        .isFileSync(globals.fs.path.join(flutterPackagePath, 'pubspec.yaml'))) {
      throwToolExit('Unable to find package:flutter in $flutterPackagePath',
          exitCode: 2);
    }

    final String flutterDriverPackagePath =
        globals.fs.path.join(flutterRoot, 'packages', 'flutter_driver');
    if (!globals.fs.isFileSync(
        globals.fs.path.join(flutterDriverPackagePath, 'pubspec.yaml'))) {
      throwToolExit(
          'Unable to find package:flutter_driver in $flutterDriverPackagePath',
          exitCode: 2);
    }
    return flutterRoot;
  }

  /// Determines the project type in an existing flutter project.
  ///
  /// If it has a .metadata file with the project_type in it, use that.
  /// If it has an android dir and an android/app dir, it's a legacy app
  /// If it has an ios dir and an ios/Flutter dir, it's a legacy app
  /// Otherwise, we don't presume to know what type of project it could be, since
  /// many of the files could be missing, and we can't really tell definitively.
  ///
  /// Throws assertion if projectDir does not exist or empty.
  /// Returns null if no project type can be determined.
  FlutterProjectType determineTemplateType(Directory projectDir) {
    assert(projectDir.existsSync() && projectDir.listSync().isNotEmpty);
    final File metadataFile = globals.fs
        .file(globals.fs.path.join(projectDir.absolute.path, '.metadata'));
    final FlutterProjectMetadata projectMetadata =
        FlutterProjectMetadata(metadataFile, globals.logger);
    if (projectMetadata.projectType != null) {
      return projectMetadata.projectType;
    }

    bool exists(List<String> path) {
      return globals.fs
          .directory(globals.fs.path
              .joinAll(<String>[projectDir.absolute.path, ...path]))
          .existsSync();
    }

    // There either wasn't any metadata, or it didn't contain the project type,
    // so try and figure out what type of project it is from the existing
    // directory structure.
    if (exists(<String>['android', 'app']) ||
        exists(<String>['ios', 'Runner']) ||
        exists(<String>['ios', 'Flutter'])) {
      return FlutterProjectType.app;
    }
    // Since we can't really be definitive on nearly-empty directories, err on
    // the side of prudence and just say we don't know.
    return null;
  }

  /// Determines the organization.
  ///
  /// If `--org` is specified in the command, returns that directly.
  /// If `--org` is not specified, returns the organization from the existing project.
  Future<String> getOrganization(Directory projectDir) async {
    String organization = stringArg('org');
    if (!argResults.wasParsed('org')) {
      final FlutterProject project = FlutterProject.fromDirectory(projectDir);
      final Set<String> existingOrganizations = await project.organizationNames;
      if (existingOrganizations.length == 1) {
        organization = existingOrganizations.first;
      } else if (existingOrganizations.length > 1) {
        throwToolExit(
            'Ambiguous organization in existing files: $existingOrganizations. '
            'The --org command line argument must be specified to recreate project.');
      }
    }
    return organization;
  }

  /// Throws with exit 2 if the project directory is illegal.
  void validateProjectDir(String dirPath,
      {String flutterRoot, bool overwrite = false}) {
    if (globals.fs.path.isWithin(flutterRoot, dirPath)) {
      throwToolExit(
          'Cannot create a project within the Flutter SDK. '
          "Target directory '$dirPath' is within the Flutter SDK at '$flutterRoot'.",
          exitCode: 2);
    }

    // If the destination directory is actually a file, then we refuse to
    // overwrite, on the theory that the user probably didn't expect it to exist.
    if (globals.fs.isFileSync(dirPath)) {
      final String message =
          "Invalid project name: '$dirPath' - refers to an existing file.";
      throwToolExit(
          overwrite
              ? '$message Refusing to overwrite a file with a directory.'
              : message,
          exitCode: 2);
    }

    if (overwrite) {
      return;
    }

    final FileSystemEntityType type = globals.fs.typeSync(dirPath);

    switch (type) {
      case FileSystemEntityType.file:
        // Do not overwrite files.
        throwToolExit("Invalid project name: '$dirPath' - file exists.",
            exitCode: 2);
        break;
      case FileSystemEntityType.link:
        // Do not overwrite links.
        throwToolExit("Invalid project name: '$dirPath' - refers to a link.",
            exitCode: 2);
        break;
      default:
    }
  }

  /// Gets the project name based.
  ///
  /// Use the current directory path name if the `--project-name` is not specified explicitly.
  String getProjectName(String projectDirPath) {
    final String projectName =
        stringArg('project-name') ?? globals.fs.path.basename(projectDirPath);
    if (!boolArg('skip-name-checks')) {
      final String error = _validateProjectName(projectName);
      if (error != null) {
        throwToolExit(error);
      }
    }
    return projectName;
  }

  Map<String, dynamic> createTemplateContext({
    String organization,
    String projectName,
    String projectDescription,
    String androidLanguage,
    String iosLanguage,
    String flutterRoot,
    bool withPluginHook = false,
    bool ios = false,
    bool android = false,
    bool web = false,
    bool linux = false,
    bool macos = false,
    bool windows = false,
  }) {
    flutterRoot = globals.fs.path.normalize(flutterRoot);

    final String pluginDartClass = _createPluginClassName(projectName);
    final String pluginClass = pluginDartClass.endsWith('Plugin')
        ? pluginDartClass
        : pluginDartClass + 'Plugin';
    final String pluginClassSnakeCase = snakeCase(pluginClass);
    final String pluginClassCapitalSnakeCase =
        pluginClassSnakeCase.toUpperCase();
    final String appleIdentifier =
        createUTIIdentifier(organization, projectName);
    final String androidIdentifier =
        createAndroidIdentifier(organization, projectName);
    // Linux uses the same scheme as the Android identifier.
    // https://developer.gnome.org/gio/stable/GApplication.html#g-application-id-is-valid
    final String linuxIdentifier = androidIdentifier;

    return <String, dynamic>{
      'organization': organization,
      'projectName': projectName,
      'androidIdentifier': androidIdentifier,
      'iosIdentifier': appleIdentifier,
      'macosIdentifier': appleIdentifier,
      'linuxIdentifier': linuxIdentifier,
      'description': projectDescription,
      'dartSdk': '$flutterRoot/bin/cache/dart-sdk',
      'androidMinApiLevel': android_common.minApiLevel,
      'androidSdkVersion': kAndroidSdkMinVersion,
      'pluginClass': pluginClass,
      'pluginClassSnakeCase': pluginClassSnakeCase,
      'pluginClassCapitalSnakeCase': pluginClassCapitalSnakeCase,
      'pluginDartClass': pluginDartClass,
      'pluginProjectUUID': Uuid().v4().toUpperCase(),
      'withPluginHook': withPluginHook,
      'androidLanguage': androidLanguage,
      'iosLanguage': iosLanguage,
      'flutterRevision': globals.flutterVersion.frameworkRevision,
      'flutterChannel': globals.flutterVersion.channel,
      'ios': ios,
      'android': android,
      'web': web,
      'linux': linux,
      'macos': macos,
      'windows': windows,
      'year': DateTime.now().year,
    };
  }

  /// Renders the template, generate files into `directory`.
  ///
  /// `templateName` should match one of directory names under flutter_tools/template/.
  /// If `overwrite` is true, overwrites existing files, `overwrite` defaults to `false`.
  Future<int> renderTemplate(
      String templateName, Directory directory, Map<String, dynamic> context,
      {bool overwrite = false}) async {
    final Template template = await Template.fromName(
      templateName,
      fileSystem: globals.fs,
      logger: globals.logger,
      templateRenderer: globals.templateRenderer,
      templateManifest: templateManifest,
    );
    return template.render(directory, context, overwriteExisting: overwrite);
  }

  /// Whether [name] is a valid Pub package.
  @visibleForTesting
  bool isValidPackageName(String name) {
    final Match match = _identifierRegExp.matchAsPrefix(name);
    return match != null &&
        match.end == name.length &&
        !_keywords.contains(name);
  }

  /// Generate application project in the `directory` using `templateCnotext`.
  ///
  /// If `overwrite` is true, overwrites existing files, `overwrite` defaults to `false`.
  Future<int> generateApp(
      Directory directory, Map<String, dynamic> templateContext,
      {bool overwrite = false, bool pluginExampleApp = false}) async {
    int generatedCount = 0;
    generatedCount += await renderTemplate('app', directory, templateContext,
        overwrite: overwrite);
    final FlutterProject project = FlutterProject.fromDirectory(directory);
    if (templateContext['android'] == true) {
      generatedCount += _injectGradleWrapper(project);
    }

    if (boolArg('pub')) {
      await pub.get(
        context: PubContext.create,
        directory: directory.path,
        offline: boolArg('offline'),
        generateSyntheticPackage: false,
      );

      await project.ensureReadyForPlatformSpecificTooling(
        androidPlatform: templateContext['android'] as bool ?? false,
        iosPlatform: templateContext['ios'] as bool ?? false,
        linuxPlatform: templateContext['linux'] as bool ?? false,
        macOSPlatform: templateContext['macos'] as bool ?? false,
        windowsPlatform: templateContext['windows'] as bool ?? false,
        webPlatform: templateContext['web'] as bool ?? false,
      );
    }
    if (templateContext['android'] == true) {
      gradle.updateLocalProperties(project: project, requireAndroidSdk: false);
    }
    return generatedCount;
  }

  // Return null if the project name is legal. Return a validation message if
  // we should disallow the project name.
  String _validateProjectName(String projectName) {
    if (!isValidPackageName(projectName)) {
      return '"$projectName" is not a valid Dart package name.\n\n'
          'See https://dart.dev/tools/pub/pubspec#name for more information.';
    }
    if (_packageDependencies.contains(projectName)) {
      return "Invalid project name: '$projectName' - this will conflict with Flutter "
          'package dependencies.';
    }
    return null;
  }

  String createAndroidIdentifier(String organization, String name) {
    // Android application ID is specified in: https://developer.android.com/studio/build/application-id
    // All characters must be alphanumeric or an underscore [a-zA-Z0-9_].
    String tmpIdentifier = '$organization.$name';
    final RegExp disallowed = RegExp(r'[^\w\.]');
    tmpIdentifier = tmpIdentifier.replaceAll(disallowed, '');

    // It must have at least two segments (one or more dots).
    final List<String> segments = tmpIdentifier
        .split('.')
        .where((String segment) => segment.isNotEmpty)
        .toList();
    while (segments.length < 2) {
      segments.add('untitled');
    }

    // Each segment must start with a letter.
    final RegExp segmentPatternRegex = RegExp(r'^[a-zA-Z][\w]*$');
    final List<String> prefixedSegments = segments.map((String segment) {
      if (!segmentPatternRegex.hasMatch(segment)) {
        return 'u' + segment;
      }
      return segment;
    }).toList();
    return prefixedSegments.join('.');
  }

  String _createPluginClassName(String name) {
    final String camelizedName = camelCase(name);
    return camelizedName[0].toUpperCase() + camelizedName.substring(1);
  }

  String createUTIIdentifier(String organization, String name) {
    // Create a UTI (https://en.wikipedia.org/wiki/Uniform_Type_Identifier) from a base name
    name = camelCase(name);
    String tmpIdentifier = '$organization.$name';
    final RegExp disallowed = RegExp(r'[^a-zA-Z0-9\-\.\u0080-\uffff]+');
    tmpIdentifier = tmpIdentifier.replaceAll(disallowed, '');

    // It must have at least two segments (one or more dots).
    final List<String> segments = tmpIdentifier
        .split('.')
        .where((String segment) => segment.isNotEmpty)
        .toList();
    while (segments.length < 2) {
      segments.add('untitled');
    }

    return segments.join('.');
  }

  Set<Uri> get templateManifest =>
      _templateManifest ??= _computeTemplateManifest();
  Set<Uri> _templateManifest;
  Set<Uri> _computeTemplateManifest() {
    final String flutterToolsAbsolutePath = globals.fs.path.join(
      Cache.flutterRoot,
      'packages',
      'flutter_tools',
    );
    final String manifestPath = globals.fs.path.join(
      flutterToolsAbsolutePath,
      'templates',
      'template_manifest.json',
    );
    final Map<String, Object> manifest = json.decode(
      globals.fs.file(manifestPath).readAsStringSync(),
    ) as Map<String, Object>;
    return Set<Uri>.from(
      (manifest['files'] as List<Object>).cast<String>().map<Uri>(
          (String path) =>
              Uri.file(globals.fs.path.join(flutterToolsAbsolutePath, path))),
    );
  }

  int _injectGradleWrapper(FlutterProject project) {
    int filesCreated = 0;
    globals.fsUtils.copyDirectorySync(
      globals.cache.getArtifactDirectory('gradle_wrapper'),
      project.android.hostAppGradleRoot,
      onFileCopied: (File sourceFile, File destinationFile) {
        filesCreated++;
        final String modes = sourceFile.statSync().modeString();
        if (modes != null && modes.contains('x')) {
          globals.os.makeExecutable(destinationFile);
        }
      },
    );
    return filesCreated;
  }
}

// A valid Dart identifier that can be used for a package, i.e. no
// capital letters.
// https://dart.dev/guides/language/language-tour#important-concepts
final RegExp _identifierRegExp = RegExp('[a-z_][a-z0-9_]*');

// non-contextual dart keywords.
//' https://dart.dev/guides/language/language-tour#keywords
const Set<String> _keywords = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'inout',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'native',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'out',
  'part',
  'patch',
  'required',
  'rethrow',
  'return',
  'set',
  'show',
  'source',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

const Set<String> _packageDependencies = <String>{
  'analyzer',
  'args',
  'async',
  'collection',
  'convert',
  'crypto',
  'flutter',
  'flutter_test',
  'front_end',
  'html',
  'http',
  'intl',
  'io',
  'isolate',
  'kernel',
  'logging',
  'matcher',
  'meta',
  'mime',
  'path',
  'plugin',
  'pool',
  'test',
  'utf',
  'watcher',
  'yaml',
};
