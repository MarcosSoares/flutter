// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';

/// Combines several TaskFunctions with trivial success value into one.
TaskFunction combine(List<TaskFunction> tasks) {
  return () async {
    for (final TaskFunction task in tasks) {
      final TaskResult result = await task();
      if (result.failed) {
        return result;
      }
    }
    return TaskResult.success(null);
  };
}

/// Defines task that creates new Flutter project, adds a local and remote
/// plugin, and then builds the specified [buildTarget].
class PluginTest {
  PluginTest(this.buildTarget, this.options, { this.pluginCreateEnvironment, this.appCreateEnvironment });

  final String buildTarget;
  final List<String> options;
  final Map<String, String> pluginCreateEnvironment;
  final Map<String, String> appCreateEnvironment;

  Future<TaskResult> call() async {
    final Directory tempDir =
        Directory.systemTemp.createTempSync('flutter_devicelab_plugin_test.');
    try {
      section('Create plugin');
      final _FlutterProject plugin = await _FlutterProject.create(
          tempDir, options, buildTarget,
          name: 'plugintest', template: 'plugin', environment: pluginCreateEnvironment);
      section('Test plugin');
      await plugin.test();
      section('Create Flutter app');
      final _FlutterProject app = await _FlutterProject.create(tempDir, options, buildTarget,
          name: 'plugintestapp', template: 'app', environment: appCreateEnvironment);
      try {
        section('Add plugins');
        await app.addPlugin('plugintest',
            pluginPath: path.join('..', 'plugintest'));
        await app.addPlugin('path_provider');
        section('Build app');
        await app.build(buildTarget);
        section('Test app');
        await app.test();
      } finally {
        await plugin.delete();
        await app.delete();
      }
      return TaskResult.success(null);
    } catch (e) {
      return TaskResult.failure(e.toString());
    } finally {
      rmTree(tempDir);
    }
  }
}

class _FlutterProject {
  _FlutterProject(this.parent, this.name);

  final Directory parent;
  final String name;

  String get rootPath => path.join(parent.path, name);

  Future<void> addPlugin(String plugin, {String pluginPath}) async {
    final File pubspec = File(path.join(rootPath, 'pubspec.yaml'));
    String content = await pubspec.readAsString();
    final String dependency =
        pluginPath != null ? '$plugin:\n    path: $pluginPath' : '$plugin:';
    content = content.replaceFirst(
      '\ndependencies:\n',
      '\ndependencies:\n  $dependency\n',
    );
    await pubspec.writeAsString(content, flush: true);
  }

  Future<void> test() async {
    await inDirectory(Directory(rootPath), () async {
      await flutter('test');
    });
  }

  static Future<_FlutterProject> create(
      Directory directory,
      List<String> options,
      String target,
      {
        String name,
        String template,
        Map<String, String> environment,
      }) async {
    await inDirectory(directory, () async {
      await flutter(
        'create',
        options: <String>[
          '--template=$template',
          '--org',
          'io.flutter.devicelab',
          ...options,
          name,
        ],
        environment: environment,
      );
    });

    final _FlutterProject project = _FlutterProject(directory, name);
    if (template == 'plugin' && target == 'ios') {
      project._reduceIOSPluginMinimumVersion(name);
    }
    return project;
  }

  // Make the platform version artificially low to test that the "deployment
  // version too low" warning is never emitted.
  void _reduceIOSPluginMinimumVersion(String plugin) {
    final File podspec = File(path.join(rootPath, 'ios', '$plugin.podspec'));
    if (!podspec.existsSync()) {
      throw TaskResult.failure('podspec file missing at ${podspec.path}');
    }
    const String versionString = "s.platform = :ios, '8.0'";
    String podspecContent = podspec.readAsStringSync();
    if (!podspecContent.contains(versionString)) {
      throw TaskResult.failure('Update this test to match plugin minimum iOS deployment version');
    }
    podspecContent = podspecContent.replaceFirst(
      versionString,
      "s.platform = :ios, '7.0'",
    );
    podspec.writeAsStringSync(podspecContent, flush: true);
  }

  Future<void> build(String target) async {
    await inDirectory(Directory(rootPath), () async {
      final String buildOutput =  await evalFlutter('build', options: <String>[target, '-v']);

      if (target == 'ios') {
        // This warning is confusing and shouldn't be emitted. Plugins often support lower versions than the
        // Flutter app, but as long as they support the minimum it will work.
        // warning: The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 8.0,
        // but the range of supported deployment target versions is 9.0 to 14.0.99.
        if (buildOutput.contains('the range of supported deployment target versions')) {
          throw TaskResult.failure('Minimum plugin version warning present');
        }
      }
    });
  }

  Future<void> delete() async {
    if (Platform.isWindows) {
      // A running Gradle daemon might prevent us from deleting the project
      // folder on Windows.
      final String wrapperPath =
          path.absolute(path.join(rootPath, 'android', 'gradlew.bat'));
      if (File(wrapperPath).existsSync()) {
        await exec(wrapperPath, <String>['--stop'], canFail: true);
      }
      // TODO(ianh): Investigating if flakiness is timing dependent.
      await Future<void>.delayed(const Duration(seconds: 10));
    }
    rmTree(parent);
  }
}
