// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

//import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

import './git.dart';
import './globals.dart' as globals;
import './stdio.dart';

class Repository {
  Repository({
    @required this.name,
    @required this.upstream,
    @required this.git,
    @required this.stdio,
    @required this.platform,
    @required this.fileSystem,
    @required this.parentDirectory,
    this.localUpstream = false,
    this.useExistingCheckout = true, // TODO: make this false
  }) {
    // These branches must exist locally for the repo that depends on it to
    // fetch and push to.
    if (localUpstream) {
      for (final String channel in globals.kReleaseChannels) {
        git.run(
          <String>['checkout', channel, '--'],
          'check out branch $channel locally',
          workingDirectory: checkoutDirectory.path,
        );
      }
    }
  }

  final String name;
  final String upstream;
  final Git git;
  final Stdio stdio;
  final Platform platform;
  final FileSystem fileSystem;
  final Directory parentDirectory;
  final bool useExistingCheckout;

  /// If the repository will be used as an upstream for a test repo.
  final bool localUpstream;

  Directory _checkoutDirectory;
  Directory get checkoutDirectory {
    if (_checkoutDirectory == null) {
      _checkoutDirectory = parentDirectory.childDirectory(name);
      if (checkoutDirectory.existsSync() && !useExistingCheckout) {
        stdio.printTrace('Deleting $name from ${checkoutDirectory.path}...');
        checkoutDirectory.deleteSync(recursive: true);
      }
      if (!checkoutDirectory.existsSync()) {
        stdio.printTrace('Cloning $name to ${checkoutDirectory.path}...');
        git.run(
          <String>['clone', '--', upstream, checkoutDirectory.path],
          'Cloning $name repo',
          workingDirectory: parentDirectory.path,
        );
      } else {
        stdio.printTrace(
            'Using existing $name repo at ${checkoutDirectory.path}...');
      }
    }
    return _checkoutDirectory;
  }

  String remoteUrl(String remoteName) {
    assert(remoteName != null);
    return git.getOutput(
      <String>['remote', 'get-url', remoteName],
      'verify the URL of the $remoteName remote',
      workingDirectory: checkoutDirectory.path,
    );
  }

  /// Verifies the repository's git checkout is clean.
  bool gitCheckoutClean() {
    final String output = git.getOutput(
      <String>['status', '--porcelain'],
      'check that the git checkout is clean',
      workingDirectory: checkoutDirectory.path,
    );
    return output == '';
  }

  void fetch(String remoteName) {
    git.run(
      <String>['fetch', remoteName],
      'fetch $remoteName',
      workingDirectory: checkoutDirectory.path,
    );
  }

  /// Obtain the version tag of the previous dev release.
  String getFullTag(String remoteName) {
    const String glob = '*.*.*-*.*.pre';
    // describe the latest dev release
    final String ref = 'refs/remotes/$remoteName/dev';
    return git.getOutput(
      <String>['describe', '--match', glob, '--exact-match', '--tags', ref],
      'obtain last released version number',
      workingDirectory: checkoutDirectory.path,
    );
  }

  String reverseParse(String ref) {
    final String revisionHash = git.getOutput(
      <String>['rev-parse', ref],
      'look up the commit for the ref $ref',
      workingDirectory: checkoutDirectory.path,
    );
    assert(revisionHash.isNotEmpty);
    return revisionHash;
  }

  bool isAncestor(String possibleAncestor, String target) {
    final int exitcode = git.run(
      <String>['merge-base', '--is-ancestor', target, possibleAncestor],
      'verify $possibleAncestor is a direct ancestor of $target. The flag '
      '`${globals.kForce}` is required to override this check.',
      allowNonZeroExitCode: true,
      workingDirectory: checkoutDirectory.path,
    );
    return exitcode == 0;
  }

  bool isCommitTagged(String commit) {
    final int exitcode = git.run(
      <String>['describe', '--exact-match', '--tags', commit],
      'verify $commit is already tagged',
      allowNonZeroExitCode: true,
      workingDirectory: checkoutDirectory.path,
    );
    return exitcode == 0;
  }

  void reset(String commit) {
    git.run(
      <String>['reset', commit, '--hard'],
      'reset to the release commit',
      workingDirectory: checkoutDirectory.path,
    );
  }

  /// Tag [commit] and push the tag to the remote.
  void tag(String commit, String tagName, String remote) {
    git.run(
      <String>['tag', tagName, commit],
      'tag the commit with the version label',
      workingDirectory: checkoutDirectory.path,
    );
    git.run(
      <String>['push', remote, tagName],
      'publish the tag to the repo',
      workingDirectory: checkoutDirectory.path,
    );
  }

  /// Push [commit] to the release channel [branch].
  void updateChannel(
    String commit,
    String remote,
    String branch, {
    bool force = false,
  }) {
    git.run(
      <String>[
        'push',
        if (force) '--force',
        remote,
        '$commit:$branch',
      ],
      'update the release branch with the commit',
      workingDirectory: checkoutDirectory.path,
    );
  }

  String authorEmptyCommit([String message = 'An empty commit']) {
    git.run(
      <String>['commit', '--allow-empty', '-m', '\'$message\''],
      'create an empty commit',
      workingDirectory: checkoutDirectory.path,
    );
    return reverseParse('HEAD');
  }

  @visibleForTesting
  Repository cloneRepository(String cloneName) {
    cloneName ??= 'clone-of-$name';
    return Repository(
      fileSystem: fileSystem,
      git: git,
      name: cloneName,
      parentDirectory: parentDirectory,
      platform: platform,
      stdio: stdio,
      upstream: 'file://${checkoutDirectory.path}/',
    );
  }
}

/// An enum of all the repositories that the Conductor supports.
enum RepositoryType {
  framework,
  engine,
}

class Checkouts {
  Checkouts({
    @required Platform platform,
    @required FileSystem fileSystem,
    @required Git git,
    Directory parentDirectory,
    String directoryName = 'checkouts',
  }) {
    if (parentDirectory != null) {
      directory = parentDirectory.childDirectory(directoryName);
    } else {
      String filePath;
      // If a test
      if (platform.script.scheme == 'data') {
        final RegExp pattern = RegExp(
          r'(file:\/\/[^"]*[/\\]conductor[/\\][^"]+\.dart)',
          multiLine: true,
        );
        final Match match =
            pattern.firstMatch(Uri.decodeFull(platform.script.path));
        if (match == null) {
          throw Exception('Cannot determine path of script!');
        }
        filePath = Uri.parse(match.group(1)).path;
      } else {
        filePath = platform.script.toFilePath();
      }
      final String checkoutsDirname = fileSystem.path.normalize(
        fileSystem.path.join(
          fileSystem.path.dirname(filePath),
          '..',
          'checkouts',
        ),
      );
      directory = fileSystem.directory(checkoutsDirname);
    }
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  Directory directory;
  FileSystem fileSystem;

  Repository addRepo({
    @required RepositoryType repoType,
    @required Git git,
    @required Stdio stdio,
    @required Platform platform,
    FileSystem fileSystem,
    String upstream,
    String name,
    bool localUpstream = false,
  }) {
    switch (repoType) {
      case RepositoryType.framework:
        name ??= 'framework';
        upstream ??= 'https://github.com/flutter/flutter.git';
        break;
      case RepositoryType.engine:
        name ??= 'engine';
        upstream ??= 'https://github.com/flutter/engine.git';
        break;
    }
    return Repository(
      name: name,
      upstream: upstream,
      git: git,
      stdio: stdio,
      platform: platform,
      fileSystem: fileSystem,
      parentDirectory: directory,
      localUpstream: localUpstream,
    );
  }
}
