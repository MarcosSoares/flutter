// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:yaml/yaml.dart';

import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/utils.dart';
import 'project.dart';
import 'version.dart';

enum FlutterProjectType {
  /// This is the default project with the user-managed host code.
  /// It is different than the "module" template in that it exposes and doesn't
  /// manage the platform code.
  app,
  /// A List/Detail app template that follows community best practices.
  skeleton,
  /// The is a project that has managed platform host code. It is an application with
  /// ephemeral .ios and .android directories that can be updated automatically.
  module,
  /// This is a Flutter Dart package project. It doesn't have any native
  /// components, only Dart.
  package,
  /// This is a native plugin project.
  plugin,
  /// This is an FFI native plugin project.
  ffiPlugin,
}

String flutterProjectTypeToString(FlutterProjectType? type) {
  if (type == null) {
    return '';
  }
  if (type == FlutterProjectType.ffiPlugin) {
    return 'plugin_ffi';
  }
  return getEnumName(type);
}

FlutterProjectType? stringToProjectType(String value) {
  FlutterProjectType? result;
  for (final FlutterProjectType type in FlutterProjectType.values) {
    if (value == flutterProjectTypeToString(type)) {
      result = type;
      break;
    }
  }
  return result;
}

  /// Verifies the expected yaml keys are present in the file.
  bool _validateMetadataMap(Object? yamlRoot, Map<String, Type> validations, Logger logger) {
    if (yamlRoot != null && yamlRoot is! YamlMap) {
      return false;
    }
    final YamlMap map = yamlRoot! as YamlMap;
    bool isValid = true;
    for (final MapEntry<String, Object> entry in validations.entries) {
      if (!map.keys.contains(entry.key)) {
        isValid = false;
        logger.printError('The key ${entry.key} was not found');
        break;
      }
      if (map[entry.key] != null && (map[entry.key] as Object).runtimeType != entry.value) {
        isValid = false;
        logger.printError('The value of key ${entry.key} was expected to be ${entry.value} but was ${(map[entry.key] as Object).runtimeType}');
        break;
      }
    }
    return isValid;
  }

/// A wrapper around the `.metadata` file.
class FlutterProjectMetadata {
  /// Creates a MigrateConfig by parsing an existing .migrate_config yaml file.
  FlutterProjectMetadata(File file, Logger logger) : _metadataFile = file,
                                                     _logger = logger,
                                                     migrateConfig = MigrateConfig() {
    if (!_metadataFile.existsSync()) {
      _logger.printError('No .metadata file found at ${_metadataFile.path}');
      // Create a default metadata.
      return;
    }
    Object? yamlRoot;
    try {
      yamlRoot = loadYaml(_metadataFile.readAsStringSync());
    } on YamlException {
      // Handled in _validate below.
    }
    if (yamlRoot == null || yamlRoot is! YamlMap) {
      return;
    }
    final YamlMap map = yamlRoot as YamlMap;
    if (_validateMetadataMap(yamlRoot, <String, Type>{'version': YamlMap}, _logger)) {
      final Object? versionYaml = map['version'];
      if (_validateMetadataMap(versionYaml, <String, Type>{
            'revision': String,
            'channel': String,
          }, _logger)) {
        final YamlMap versionYamlMap = versionYaml! as YamlMap;
        _versionRevision = versionYamlMap['revision'] as String?;
        _versionChannel = versionYamlMap['channel'] as String?;
      } else {
        _logger.printTrace('.metadata version is malformed.');
      }
    }
    if (_validateMetadataMap(yamlRoot, <String, Type>{'project_type': String}, _logger)) {
      _projectType = stringToProjectType(map['project_type'] as String);
    }
    final Object? migrationYaml = map['migration'];
    if (migrationYaml != null && migrationYaml is YamlMap) {
      migrateConfig.parseYaml(map['migration'] as YamlMap, _logger);
    }
  }

  /// Creates a MigrateConfig by explicitly providing all values.
  FlutterProjectMetadata.explicit({
    required File file,
    required String? versionRevision,
    required String? versionChannel,
    required FlutterProjectType? projectType,
    required this.migrateConfig,
    required Logger logger,
  }) : _logger = logger,
       _versionChannel = versionChannel,
       _versionRevision = versionRevision,
       _projectType = projectType,
       _metadataFile = file;

  /// The name of the config file.
  static const String kFileName = '.metadata';

  String? _versionRevision;
  String? get versionRevision => _versionRevision;

  String? _versionChannel;
  String? get versionChannel => _versionChannel;

  FlutterProjectType? _projectType;
  FlutterProjectType? get projectType => _projectType;

  /// Metadata and configuration for the migrate command.
  MigrateConfig migrateConfig;

  final Logger _logger;

  final File _metadataFile;

  /// Writes the .migrate_config file in the provided project directory's platform subdirectory.
  ///
  /// We write the file manually instead of with a template because this
  /// needs to be able to write the .migrate_config file into legacy apps.
  void writeFile() {
    _metadataFile
      ..createSync(recursive: true)
      ..writeAsStringSync('''
# This file tracks properties of this Flutter project.
# Used by Flutter tool to assess capabilities and perform upgrades etc.
#
# This file should be version controlled.

version:
  revision: $_versionRevision
  channel: $_versionChannel

project_type: ${flutterProjectTypeToString(projectType)}
${migrateConfig.getOutputFileString()}''',
    flush: true);
  }

  void populate({
    List<SupportedPlatform>? platforms,
    Directory? projectDirectory,
    String? currentRevision,
    String? createRevision,
    bool create = true,
    bool update = true,
    required Logger logger,
  }) {
    migrateConfig.populate(
      platforms: platforms,
      projectDirectory: projectDirectory,
      currentRevision: currentRevision,
      createRevision: createRevision,
      create: create,
      update: update,
      logger: logger,
    );
  }

  /// Finds the fallback revision to use when no base revision is found in the migrate config.
  String getFallbackBaseRevision(Logger logger, FlutterVersion flutterVersion) {
    // Use the .metadata file if it exists.
    if (versionRevision != null) {
      return versionRevision!;
    }
    return flutterVersion.frameworkRevision;
  }
}

/// Represents the migrate command metadata section of a .metadata file.
///
/// This file tracks the flutter sdk git hashes of the last successful migration ('base') and
/// the version the project was created with.
///
/// Each platform tracks a different set of revisions because flutter create can be
/// used to add support for new platforms, so the base and create revision may not always be the same.
class MigrateConfig {
  MigrateConfig({
    Map<SupportedPlatform, MigratePlatformConfig>? platformConfigs,
    this.unmanagedFiles = _kDefaultUnmanagedFiles
  }) : platformConfigs = platformConfigs ?? <SupportedPlatform, MigratePlatformConfig>{};

  /// A mapping of the files that are unmanaged by defult for each platform.
  static const List<String> _kDefaultUnmanagedFiles = <String>[
    'lib/main.dart',
    'ios/Runner.xcodeproj/project.pbxproj',
  ];

  /// The metadata for each platform supported by the project.
  final Map<SupportedPlatform, MigratePlatformConfig> platformConfigs;

  /// A list of paths relative to this file the migrate tool should ignore.
  ///
  /// These files are typically user-owned files that should not be changed.
  List<String> unmanagedFiles;

  bool get isEmpty => platformConfigs.isEmpty && (unmanagedFiles.isEmpty || unmanagedFiles == _kDefaultUnmanagedFiles);

  /// Parses the project for all supported platforms and populates the MigrateConfig
  /// to reflect the project.
  void populate({
    List<SupportedPlatform>? platforms,
    Directory? projectDirectory,
    String? currentRevision,
    String? createRevision,
    bool create = true,
    bool update = true,
    required Logger logger,
  }) {
    final FlutterProject flutterProject = projectDirectory == null ? FlutterProject.current() : FlutterProject.fromDirectory(projectDirectory);
    platforms ??= flutterProject.getSupportedPlatforms(includeRoot: true);

    for (final SupportedPlatform platform in platforms) {
      if (platformConfigs.containsKey(platform)) {
        if (update) {
          platformConfigs[platform]!.baseRevision = currentRevision;
        }
      } else {
        if (create) {
          platformConfigs[platform] = MigratePlatformConfig(createRevision: createRevision, baseRevision: currentRevision);
        }
      }
    }
  }

  /// Returns the string that should be written to the .metadata file.
  String getOutputFileString() {
    String unmanagedFilesString = '';
    for (final String path in unmanagedFiles) {
      unmanagedFilesString += "\n    - '$path'";
    }

    String platformsString = '';
    for (final MapEntry<SupportedPlatform, MigratePlatformConfig> entry in platformConfigs.entries) {
      platformsString += '\n    - platform: ${entry.key.toString().split('.').last}\n      create_revision: ${entry.value.createRevision == null ? 'null' : "${entry.value.createRevision}"}\n      base_revision: ${entry.value.baseRevision == null ? 'null' : "${entry.value.baseRevision}"}';
    }

    return isEmpty ? '' : '''

# Tracks metadata for the flutter migrate command
migration:
  platforms:$platformsString

  # User provided section

  # List of Local paths (relative to this file) that should be
  # ignored by the migrate tool.
  #
  # Files that are not part of the templates will be ignored by default.
  unmanaged_files:$unmanagedFilesString
''';
  }

  /// Parses and validates the `migration` section of the .metadata file.
  void parseYaml(YamlMap map, Logger logger) {
    final Object? platformsYaml = map['platforms'];
    if (!_validateMetadataMap(map, <String, Type>{
          'platforms': YamlList,
          'unmanaged_files': YamlList,
        }, logger)) {
      return;
    }
    if (platformsYaml is YamlList && platformsYaml.isNotEmpty) {
      for (final Object? platform in platformsYaml) {
        if (_validateMetadataMap(platform, <String, Type>{
              'platform': String,
              'create_revision': String,
              'base_revision': String,
            }, logger)) {
          final YamlMap platformYamlMap = platform! as YamlMap;
          final SupportedPlatform platformString = SupportedPlatform.values.firstWhere(
            (SupportedPlatform val) => val.toString() == 'SupportedPlatform.${platformYamlMap['platform'] as String}'
          );
          platformConfigs[platformString] = MigratePlatformConfig(
            createRevision: platformYamlMap['create_revision'] as String?,
            baseRevision: platformYamlMap['base_revision'] as String?,
          );
        } else {
          // malformed platform entry
          continue;
        }
      }
    }

    final Object? unmanagedFilesYaml = map['unmanaged_files'];
    if (unmanagedFilesYaml is YamlList && unmanagedFilesYaml.isNotEmpty) {
      unmanagedFiles = List<String>.from(unmanagedFilesYaml.value.cast<String>());
    }
  }
}

/// Holds the revisions for a single platform for use by the flutter migrate command.
class MigratePlatformConfig {
  MigratePlatformConfig({this.createRevision, this.baseRevision});

  /// The Flutter SDK revision this platform was created by.
  ///
  /// Null if the initial create git revision is unknown.
  final String? createRevision;

  /// The Flutter SDK revision this platform was last migrated by.
  ///
  /// Null if the project was never migrated or the revision is unknown.
  String? baseRevision;
}
