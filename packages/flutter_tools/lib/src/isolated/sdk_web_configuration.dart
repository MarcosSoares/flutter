// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';

import 'package:dwds/dwds.dart';

import '../artifacts.dart';
import '../base/file_system.dart';
import '../globals.dart' as globals;

/// Provides paths to SDK files for dart SDK used in flutter.
class SdkWebConfigurationProvider extends SdkConfigurationProvider {
  SdkWebConfigurationProvider();
  SdkConfiguration _configuration;

  /// Create and validate configuration matching the default SDK layout.
  /// Create configuration matching the default SDK layout.
  @override
  Future<SdkConfiguration> get configuration async {
    if (_configuration == null) {
      final String sdkDir = globals.artifacts.getHostArtifact(HostArtifact.flutterWebSdk).path;
      final String unsoundSdkSummaryPath = globals.artifacts.getHostArtifact(HostArtifact.webPlatformKernelDill).path;
      final String soundSdkSummaryPath = globals.artifacts.getHostArtifact(HostArtifact.webPlatformSoundKernelDill).path;
      final String librariesPath = globals.artifacts.getHostArtifact(HostArtifact.flutterWebLibrariesJson).path;

      _configuration = SdkConfiguration(
        sdkDirectory: sdkDir,
        unsoundSdkSummaryPath: unsoundSdkSummaryPath,
        soundSdkSummaryPath: soundSdkSummaryPath,
        librariesPath: librariesPath,
      );
    }
    return _configuration;
  }

  /// Validate that SDK configuration exists on disk.
  static void validate(SdkConfiguration configuration, { FileSystem fileSystem }) {
    configuration.validateSdkDir(fileSystem: fileSystem);
    configuration.validateSummaries(fileSystem: fileSystem);
    configuration.validateLibrariesSpec(fileSystem: fileSystem);
  }
}
