// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/custom_devices/custom_device_config.dart';
import 'package:flutter_tools/src/project.dart';
import 'package:meta/meta.dart';

void writeCustomDevicesConfigFile(
  Directory dir, {
  List<CustomDeviceConfig>? configs,
  dynamic json
}) {
  dir.createSync(recursive: true);

  final File file = dir.childFile('.flutter_custom_devices.json');
  file.writeAsStringSync(jsonEncode(
    <String, dynamic>{
      'custom-devices': configs != null ?
        configs.map<dynamic>((CustomDeviceConfig c) => c.toJson()).toList() :
        json
    },
  ));
}

final CustomDeviceConfig testConfig = CustomDeviceConfig(
  id: 'testid',
  label: 'testlabel',
  sdkNameAndVersion: 'testsdknameandversion',
  enabled: true,
  pingCommand: const <String>['testping'],
  pingSuccessRegex: RegExp('testpingsuccess'),
  postBuildCommand: const <String>['testpostbuild'],
  installCommand: const <String>['testinstall'],
  uninstallCommand: const <String>['testuninstall'],
  runDebugCommand: const <String>['testrundebug'],
  forwardPortCommand: const <String>['testforwardport'],
  forwardPortSuccessRegex: RegExp('testforwardportsuccess')
);

const String testConfigPingSuccessOutput = 'testpingsuccess\n';
const String testConfigForwardPortSuccessOutput = 'testforwardportsuccess\n';
final CustomDeviceConfig disabledTestConfig = testConfig.copyWith(enabled: false);
final CustomDeviceConfig testConfigNonForwarding = testConfig.copyWith(
  explicitForwardPortCommand: true,
  explicitForwardPortSuccessRegex: true,
);

const Map<String, dynamic> testConfigJson = <String, dynamic>{
  'id': 'testid',
  'label': 'testlabel',
  'sdkNameAndVersion': 'testsdknameandversion',
  'enabled': true,
  'ping': <String>['testping'],
  'pingSuccessRegex': 'testpingsuccess',
  'postBuild': <String>['testpostbuild'],
  'install': <String>['testinstall'],
  'uninstall': <String>['testuninstall'],
  'runDebug': <String>['testrundebug'],
  'forwardPort': <String>['testforwardport'],
  'forwardPortSuccessRegex': 'testforwardportsuccess'
};

final CustomDeviceConfig testConfigPlugins = testConfig.copyWith(
  embedderName: 'testembedder',
  configureNativeProject: const <String>['testconfigurenativeproject', r'${buildType}', r'${pluginList}', r'${assetBuildDirectory}'],
  buildNativeProject: const <String>['testbuildnativeproject', r'${buildType}', r'${pluginList}', r'${assetBuildDirectory}']
);

const Map<String, dynamic> testConfigPluginsJson = <String, dynamic>{
  'id': 'testid',
  'label': 'testlabel',
  'sdkNameAndVersion': 'testsdknameandversion',
  'enabled': true,
  'ping': <String>['testping'],
  'pingSuccessRegex': 'testpingsuccess',
  'postBuild': <String>['testpostbuild'],
  'install': <String>['testinstall'],
  'uninstall': <String>['testuninstall'],
  'runDebug': <String>['testrundebug'],
  'forwardPort': <String>['testforwardport'],
  'forwardPortSuccessRegex': 'testforwardportsuccess',
  'embedder': 'testembedder',
  'configureNativeProject': <String>['testconfigurenativeproject', r'${buildType}', r'${pluginList}', r'${assetBundleDirectory}'],
  'buildNativeProject': <String>['testbuildnativeproject', r'${buildType}', r'${pluginList}', r'${assetBundleDirectory}']
};

typedef BundleBuildFunction = Future<void> Function({
  TargetPlatform? platform,
  BuildInfo? buildInfo,
  FlutterProject? project,
  String? mainPath,
  String? manifestPath,
  String? applicationKernelFilePath,
  String? depfilePath,
  String? assetDirPath,
  @visibleForTesting BuildSystem? buildSystem
});
