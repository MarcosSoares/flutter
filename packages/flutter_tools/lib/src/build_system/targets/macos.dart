// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../base/file_system.dart';
import '../../base/io.dart';
import '../../base/process_manager.dart';
import '../build_system.dart';

/// Copy the macOS framework to the correct copy dir by invoking 'cp -R'.
///
/// The shelling out is done to avoid complications with preserving special
/// files (e.g., symbolic links) in the framework structure.
///
/// Removes any previous version of the framework that already exists in the
/// target directory.
Future<void> copyFramework(Map<String, ChangeType> updates,
    Environment environment) async {
  // Ensure that the path is a framework, to minimize the potential for
  // catastrophic deletion bugs with bad arguments.
  if (fs.path.extension(updates.keys.single) != '.framework') {
    throw Exception('Attempted to delete a non-framework directory: ${updates.keys.single}');
  }
  final Directory input = fs.directory(updates.keys.single);
  final Directory targetDirectory = environment
    .projectDir
    .childDirectory('macos')
    .childDirectory('Flutter')
    .childDirectory('FlutterMacOS.framework');
  if (targetDirectory.existsSync()) {
    targetDirectory.deleteSync(recursive: true);
  }

  final ProcessResult result = processManager
      .runSync(<String>['cp', '-R', input.path, targetDirectory.path]);
  if (result.exitCode != 0) {
    throw Exception(
      'Failed to copy framework (exit ${result.exitCode}:\n'
      '${result.stdout}\n---\n${result.stderr}',
    );
  }
}

/// Copies the macOS desktop framework to the copy directory.
const Target unpackMacos = Target(
  name: 'unpack_macos',
  inputs: <Source>[
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/FlutterMacOS'),
    // Headers
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FLEOpenGLContextHandling.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FLEReshapeListener.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FLEView.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FLEViewController.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FlutterBinaryMessenger.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FlutterChannels.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FlutterCodecs.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FlutterMacOS.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FlutterPluginMacOS.h'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Headers/FlutterPluginRegisrarMacOS.h'),
    // Modules
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Modules/module.modulemap'),
    // Resources
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Resources/icudtl.dat'),
    Source.pattern('{CACHE_DIR}/engine/darwin-x64/FlutterMacOS.framework/Resources/info.plist'),
    // Ignore Versions folder for now
  ],
  outputs: <Source>[
    Source.pattern('{PROJECT_DIR}/macos/Flutter/FlutterMacOS.framework/'),
  ],
  dependencies: <Target>[],
  buildAction: copyFramework,
);
