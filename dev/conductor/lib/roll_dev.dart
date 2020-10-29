// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';

import './globals.dart';
import './repository.dart';
import './stdio.dart';
import './version.dart';

class RollDev extends Command<void> {
  factory RollDev() {
    const FileSystem fileSystem = LocalFileSystem();
    const ProcessManager processManager = LocalProcessManager();
    const Platform platform = LocalPlatform();
    final Stdio stdio = VerboseStdio(
      stdout: io.stdout,
      stderr: io.stderr,
      stdin: io.stdin,
    );
    final Checkouts checkouts = Checkouts(
      fileSystem: fileSystem,
      platform: platform,
      processManager: processManager,
    );
    return RollDev._(
      fileSystem: fileSystem,
      platform: platform,
      repository: checkouts.addRepo(
        fileSystem: fileSystem,
        platform: platform,
        repoType: RepositoryType.framework,
        stdio: stdio,
      ),
      stdio: stdio,
    );
  }

  RollDev._({
    this.fileSystem,
    this.platform,
    this.repository,
    this.stdio,
  }) {
    argParser.addOption(
      kIncrement,
      help: 'Specifies which part of the x.y.z version number to increment. Required.',
      valueHelp: 'level',
      allowed: <String>[kY, kZ, 'm', 'n'],
      allowedHelp: <String, String>{
        kY: 'Indicates a minor development, e.g. typically changed after a beta release.',
        kZ: 'Indicates a hotfix to a stable release.',
      },
    );
    argParser.addOption(
      kCommit,
      help: 'Specifies which git commit to roll to the dev branch. Required.',
      valueHelp: 'hash',
      defaultsTo: null, // This option is required
    );
    argParser.addFlag(
      kForce,
      abbr: 'f',
      help: 'Force push. Necessary when the previous release had cherry-picks.',
      negatable: false,
    );
    argParser.addFlag(
      kJustPrint,
      negatable: false,
      help:
          "Don't actually roll the dev channel; "
          'just print the would-be version and quit.',
    );
    argParser.addFlag(
      kSkipTagging,
      negatable: false,
      help: 'Do not create tag and push to remote, only update release branch. '
      'For recovering when the script fails trying to git push to the release branch.'
    );
    argParser.addFlag(kYes, negatable: false, abbr: 'y', help: 'Skip the confirmation prompt.');
  }

  final FileSystem fileSystem;
  final Platform platform;
  final Stdio stdio;
  final Repository repository;

  @override
  String get name => 'roll-dev';

  @override
  String get description =>
      'For publishing a dev release without cherry picks.';

  @override
  void run() {
    rollDev(
      argResults: argResults,
      fileSystem: fileSystem,
      platform: platform,
      repository: repository,
      stdio: stdio,
      usage: argParser.usage,
    );
  }
}

/// Main script execution.
///
/// Returns true if publishing was successful, else false.
@visibleForTesting
bool rollDev({
  @required String usage,
  @required ArgResults argResults,
  @required Stdio stdio,
  @required Platform platform,
  @required FileSystem fileSystem,
  @required Repository repository,
  String remoteName = 'origin',
}) {
  final String level = argResults[kIncrement] as String;
  final String commit = argResults[kCommit] as String;
  final bool justPrint = argResults[kJustPrint] as bool;
  final bool autoApprove = argResults[kYes] as bool;
  final bool force = argResults[kForce] as bool;
  final bool skipTagging = argResults[kSkipTagging] as bool;

  if (level == null || commit == null) {
    stdio.printStatus(
        'roll_dev.dart --increment=level --commit=hash • update the version tags '
        'and roll a new dev build.\n$usage');
    return false;
  }

  final String remoteUrl = repository.remoteUrl(remoteName);

  if (!repository.gitCheckoutClean()) {
    throw Exception(
        'Your git repository is not clean. Try running "git clean -fd". Warning, '
        'this will delete files! Run with -n to find out which ones.');
  }

  repository.fetch(remoteName);

  // Verify [commit] is valid
  repository.reverseParse(commit);

  stdio.printStatus('remoteName is $remoteName');
  final Version lastVersion =
      Version.fromString(repository.getFullTag(remoteName));

  print('about to increment $lastVersion'); // TODO
  final Version version =
      skipTagging ? lastVersion : Version.increment(lastVersion, level);
  print('post increment $version'); // TODO
  final String tagName = version.toString();

  if (repository.reverseParse(lastVersion.toString()).contains(commit.trim())) {
    throw Exception(
        'Commit $commit is already on the dev branch as $lastVersion.');
  }

  if (justPrint) {
    stdio.printStatus(tagName);
    return false;
  }

  if (skipTagging && !repository.isCommitTagged(commit)) {
    throw Exception(
        'The $kSkipTagging flag is only supported for tagged commits.');
  }

  if (!force && !repository.isAncestor(commit, lastVersion.toString())) {
    throw Exception(
        'The previous dev tag $lastVersion is not a direct ancestor of $commit.\n'
        'The flag "$kForce" is required to force push a new release past a cherry-pick.');
  }

  final String hash = repository.reverseParse(commit);

  // [commit] can be a prefix for [hash].
  assert(hash.startsWith(commit));

  // PROMPT
  if (autoApprove) {
    stdio.printStatus(
        'Publishing Flutter $version ($hash) to the "dev" channel.');
  } else {
    stdio.printStatus('Your tree is ready to publish Flutter $version '
        '($hash) to the "dev" channel.');
    stdio.write('Are you? [yes/no] ');
    if (stdio.readLineSync() != 'yes') {
      stdio.printError('The dev roll has been aborted.');
      return false;
    }
  }

  if (!skipTagging) {
    repository.tag(commit, version.toString(), remoteName);
  }

  repository.updateChannel(
    commit,
    remoteName,
    'dev',
    force: force,
  );

  stdio.printStatus(
    'Flutter version $version has been rolled to the "dev" channel at $remoteUrl.',
  );
  return true;
}
