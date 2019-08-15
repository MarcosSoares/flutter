// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pool/pool.dart';

import '../../artifacts.dart';
import '../../asset.dart';
import '../../base/file_system.dart';
import '../../base/io.dart';
import '../../base/process.dart';
import '../../base/process_manager.dart';
import '../../build_info.dart';
import '../../devfs.dart';
import '../../globals.dart';
import '../../macos/xcode.dart';
import '../../project.dart';
import '../build_system.dart';
import 'dart.dart';

const String _kOutputPrefix = '{PROJECT_DIR}/macos/Flutter/ephemeral/FlutterMacOS.framework';

/// The copying logic for flutter assets in macOS.
// TODO(jonahwilliams): remove once build planning lands.
class MacOSAssetBehavior extends SourceBehavior {
  const MacOSAssetBehavior();

  @override
  List<File> inputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    // Filter the file type to remove the files that are generated by this
    // command as inputs.
    final List<File> results = <File>[];
    final Iterable<DevFSFileContent> files = assetBundle.entries.values.whereType<DevFSFileContent>();
    for (DevFSFileContent devFsContent in files) {
      results.add(fs.file(devFsContent.file.path));
    }
    return results;
  }

  @override
  List<File> outputs(Environment environment) {
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    final FlutterProject flutterProject = FlutterProject.fromDirectory(environment.projectDir);
    final String prefix = fs.path.join(flutterProject.macos.ephemeralDirectory.path,
        'App.framework', 'flutter_assets');
    final List<File> results = <File>[];
    for (String key in assetBundle.entries.keys) {
      final File file = fs.file(fs.path.join(prefix, key));
      results.add(file);
    }
    return results;
  }
}

/// Copy the macOS framework to the correct copy dir by invoking 'cp -R'.
///
/// The shelling out is done to avoid complications with preserving special
/// files (e.g., symbolic links) in the framework structure.
///
/// Removes any previous version of the framework that already exists in the
/// target directory.
// TODO(jonahwilliams): remove shell out.
class UnpackMacOS extends Target {
  const UnpackMacOS();

  @override
  String get name => 'unpack_macos';

  @override
  List<Source> get inputs => const <Source>[
    Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/macos.dart'),
    Source.artifact(Artifact.flutterMacOSFramework),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.pattern('$_kOutputPrefix/FlutterMacOS'),
    // Headers
    Source.pattern('$_kOutputPrefix/Headers/FlutterDartProject.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterEngine.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterViewController.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterBinaryMessenger.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterChannels.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterCodecs.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterMacros.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterPluginMacOS.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterPluginRegistrarMacOS.h'),
    Source.pattern('$_kOutputPrefix/Headers/FlutterMacOS.h'),
    // Modules
    Source.pattern('$_kOutputPrefix/Modules/module.modulemap'),
    // Resources
    Source.pattern('$_kOutputPrefix/Resources/icudtl.dat'),
    Source.pattern('$_kOutputPrefix/Resources/Info.plist'),
    // Ignore Versions folder for now
  ];

  @override
  List<Target> get dependencies => <Target>[];

  @override
  Future<void> build(List<File> inputFiles, Environment environment) async {
    final String basePath = artifacts.getArtifactPath(Artifact.flutterMacOSFramework);
    final FlutterProject flutterProject = FlutterProject.fromDirectory(environment.projectDir);
    final Directory targetDirectory = flutterProject.macos
      .ephemeralDirectory
      .childDirectory('FlutterMacOS.framework');
    if (targetDirectory.existsSync()) {
      targetDirectory.deleteSync(recursive: true);
    }

    final ProcessResult result = await processManager
        .run(<String>['cp', '-R', basePath, targetDirectory.path]);
    if (result.exitCode != 0) {
      throw Exception(
        'Failed to copy framework (exit ${result.exitCode}:\n'
        '${result.stdout}\n---\n${result.stderr}',
      );
    }
  }
}

/// Create an App.framework for debug macOS targets.
///
/// This framework needs to exist for the Xcode project to link/bundle,
/// but it isn't actually executed. To generate something valid, we compile a trivial
/// constant.
class DebugMacOSFramework extends Target {
  const DebugMacOSFramework();

  @override
  String get name => 'debug_macos_framework';

  @override
  Future<void> build(List<File> inputFiles, Environment environment) async {
    final FlutterProject flutterProject = FlutterProject.fromDirectory(environment.projectDir);
    final File outputFile = fs.file(fs.path.join(
        flutterProject.macos.ephemeralDirectory.path, 'App.framework', 'App'));
    outputFile.createSync(recursive: true);
    final File debugApp = environment.buildDir.childFile('debug_app.cc')
        ..writeAsStringSync(r'''
static const int Moo = 88;
''');
    final RunResult result = await xcode.clang(<String>[
      '-x',
      'c',
      debugApp.path,
      '-arch', 'x86_64',
      '-dynamiclib',
      '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks',
      '-Xlinker', '-rpath', '-Xlinker', '@loader_path/Frameworks',
      '-install_name', '@rpath/App.framework/App',
      '-o', 'macos/Flutter/ephemeral/App.framework/App',
    ]);
    if (result.exitCode != 0) {
      throw Exception('Failed to compile debug App.framework');
    }
  }

  @override
  List<Target> get dependencies => const <Target>[];

  @override
  List<Source> get inputs => const <Source>[
    Source.pattern('{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/macos.dart'),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/App'),
  ];
}

/// Bundle the flutter assets, app.dill, and precompiled runtimes into the App.framework.
class DebugBundleFlutterAssets extends Target {
  const DebugBundleFlutterAssets();

  @override
  String get name => 'debug_bundle_flutter_assets';

  @override
  Future<void> build(List<File> inputFiles, Environment environment) async {
    final FlutterProject flutterProject = FlutterProject.fromDirectory(environment.projectDir);
    final Directory outputDirectory = flutterProject.macos
        .ephemeralDirectory.childDirectory('App.framework');
    if (!outputDirectory.existsSync()) {
      throw Exception('App.framework must exist to bundle assets.');
    }
    // Copy assets into asset directory.
    final Directory assetDirectory = outputDirectory.childDirectory('flutter_assets');
    // We're not smart enough to only remove assets that are removed. If
    // anything changes blow away the whole directory.
    if (assetDirectory.existsSync()) {
      assetDirectory.deleteSync(recursive: true);
    }
    assetDirectory.createSync();
    final AssetBundle assetBundle = AssetBundleFactory.instance.createBundle();
    final int result = await assetBundle.build(
      manifestPath: environment.projectDir.childFile('pubspec.yaml').path,
      packagesPath: environment.projectDir.childFile('.packages').path,
    );
    if (result != 0) {
      throw Exception('Failed to create asset bundle: $result');
    }
    // Limit number of open files to avoid running out of file descriptors.
    try {
      final Pool pool = Pool(64);
      await Future.wait<void>(
        assetBundle.entries.entries.map<Future<void>>((MapEntry<String, DevFSContent> entry) async {
          final PoolResource resource = await pool.request();
          try {
            final File file = fs.file(fs.path.join(assetDirectory.path, entry.key));
            file.parent.createSync(recursive: true);
            await file.writeAsBytes(await entry.value.contentsAsBytes());
          } finally {
            resource.release();
          }
        }));
    } catch (err, st){
      throw Exception('Failed to copy assets: $st');
    }
    // Copy dill file.
    try {
      final File sourceFile = environment.buildDir.childFile('app.dill');
      sourceFile.copySync(assetDirectory.childFile('kernel_blob.bin').path);
    } catch (err) {
      throw Exception('Failed to copy app.dill: $err');
    }
    // Copy precompiled runtimes.
    try {
      final String vmSnapshotData = artifacts.getArtifactPath(Artifact.vmSnapshotData,
          platform: TargetPlatform.darwin_x64, mode: BuildMode.debug);
      final String isolateSnapshotData = artifacts.getArtifactPath(Artifact.isolateSnapshotData,
          platform: TargetPlatform.darwin_x64, mode: BuildMode.debug);
      fs.file(vmSnapshotData).copySync(
          assetDirectory.childFile('vm_snapshot_data').path);
      fs.file(isolateSnapshotData).copySync(
          assetDirectory.childFile('isolate_snapshot_data').path);
    } catch (err) {
      throw Exception('Failed to copy precompiled runtimes: $err');
    }
  }

  @override
  List<Target> get dependencies => const <Target>[
    KernelSnapshot(),
    DebugMacOSFramework(),
    UnpackMacOS(),
  ];

  @override
  List<Source> get inputs => const <Source>[
    Source.behavior(MacOSAssetBehavior()),
    Source.pattern('{BUILD_DIR}/app.dill'),
    Source.artifact(Artifact.isolateSnapshotData, platform: TargetPlatform.darwin_x64, mode: BuildMode.debug),
    Source.artifact(Artifact.vmSnapshotData, platform: TargetPlatform.darwin_x64, mode: BuildMode.debug),
  ];

  @override
  List<Source> get outputs => const <Source>[
    Source.behavior(MacOSAssetBehavior()),
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/flutter_assets/AssetManifest.json'),
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/flutter_assets/FontManifest.json'),
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/flutter_assets/LICENSE'),
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/flutter_assets/kernel_blob.bin'),
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/flutter_assets/vm_snapshot_data'),
    Source.pattern('{PROJECT_DIR}/macos/Flutter/ephemeral/App.framework/flutter_assets/isolate_snapshot_data'),
  ];
}
