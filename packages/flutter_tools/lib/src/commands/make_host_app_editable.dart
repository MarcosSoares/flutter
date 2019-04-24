// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import '../base/common.dart';
import '../project.dart';
import '../runner/flutter_command.dart';

class MakeHostAppEditableCommand extends FlutterCommand {
  MakeHostAppEditableCommand() {
    requiresPubspecYaml();

    argParser.addFlag(
      'ios',
      help: 'Whether to make this project\'s iOS app editable.',
      negatable: false,
    );
    argParser.addFlag(
      'android',
      help: 'Whether ot make this project\'s Android app editable.',
      negatable: false,
    );
  }

  FlutterProject _project;

  @override
  final String name = 'make-host-app-editable';

  @override
  final String description = 'Moves host apps from generated directories to non-generated directories so that they can be edited by developers.\n\n'
    'Use flags to specify which host app to make editable. If no flags are provided then all host apps will be made editable.\n\n'
    'Once a host app is made editable, that host app cannot be regenerated by Flutter and it will not receive future template changes.';

  @override
  Future<void> validateCommand() async {
    await super.validateCommand();
    _project = await FlutterProject.current();
    if (!_project.isModule)
      throw ToolExit("Only projects created using 'flutter create -t module' can have their host apps made editable.");
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    await _project.ensureReadyForPlatformSpecificTooling(checkProjects: false);

    final bool isAndroidRequested = argResults['android'];
    final bool isIOSRequested = argResults['ios'];

    if (isAndroidRequested == isIOSRequested) {
      // No flags provided, or both flags provided. Make Android and iOS host
      // apps editable.
      await _project.android.makeHostAppEditable();
      await _project.ios.makeHostAppEditable();
    } else if (isAndroidRequested) {
      await _project.android.makeHostAppEditable();
    } else if (isIOSRequested) {
      await _project.ios.makeHostAppEditable();
    }

    return null;
  }
}
