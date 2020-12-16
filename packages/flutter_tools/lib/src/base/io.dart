// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This file serves as the single point of entry into the `dart:io` APIs
/// within Flutter tools.
///
/// In order to make Flutter tools more testable, we use the `FileSystem` APIs
/// in `package:file` rather than using the `dart:io` file APIs directly (see
/// `file_system.dart`). Doing so allows us to swap out local file system
/// access with mockable (or in-memory) file systems, making our tests hermetic
/// vis-a-vis file system access.
///
/// We also use `package:platform` to provide an abstraction away from the
/// static methods in the `dart:io` `Platform` class (see `platform.dart`). As
/// such, do not export Platform from this file!
///
/// To ensure that all file system and platform API access within Flutter tools
/// goes through the proper APIs, we forbid direct imports of `dart:io` (via a
/// test), forcing all callers to instead import this file, which exports the
/// blessed subset of `dart:io` that is legal to use in Flutter tools.
///
/// Because of the nature of this file, it is important that **platform and file
/// APIs not be exported from `dart:io` in this file**! Moreover, be careful
/// about any additional exports that you add to this file, as doing so will
/// increase the API surface that we have to test in Flutter tools, and the APIs
/// in `dart:io` can sometimes be hard to use in tests.
import 'dart:async';
import 'dart:io' as io
  show
    exit,
    InternetAddress,
    InternetAddressType,
    IOSink,
    NetworkInterface,
    pid,
    Process,
    ProcessInfo,
    ProcessSignal,
    stderr,
    stdin,
    Stdin,
    StdinException,
    Stdout,
    StdoutException,
    stdout;

import 'package:meta/meta.dart';

import '../globals.dart' as globals;
import 'async_guard.dart';
import 'context.dart';
import 'process.dart';

export 'dart:io'
    show
        BytesBuilder,
        CompressionOptions,
        // Directory,         NO! Use `file_system.dart`
        exitCode,
        // File,              NO! Use `file_system.dart`
        // FileSystemEntity,  NO! Use `file_system.dart`
        gzip,
        GZipCodec,
        HandshakeException,
        HttpClient,
        HttpClientRequest,
        HttpClientResponse,
        HttpClientResponseCompressionState,
        HttpException,
        HttpHeaders,
        HttpRequest,
        HttpResponse,
        HttpServer,
        HttpStatus,
        InternetAddress,
        InternetAddressType,
        IOException,
        IOSink,
        // Link              NO! Use `file_system.dart`
        // NetworkInterface  NO! Use `io.dart`
        OSError,
        pid,
        // Platform          NO! use `platform.dart`
        Process,
        ProcessException,
        // ProcessInfo,      NO! use `io.dart`
        ProcessResult,
        // ProcessSignal     NO! Use [ProcessSignal] below.
        ProcessStartMode,
        // RandomAccessFile  NO! Use `file_system.dart`
        ServerSocket,
        SignalException,
        // stderr,           NO! Use `io.dart`
        // stdin,            NO! Use `io.dart`
        Stdin,
        StdinException,
        // stdout,           NO! Use `io.dart`
        Stdout,
        Socket,
        SocketException,
        systemEncoding,
        WebSocket,
        WebSocketException,
        WebSocketTransformer,
        ZLibEncoder;

/// Exits the process with the given [exitCode].
typedef ExitFunction = void Function(int exitCode);

const ExitFunction _defaultExitFunction = io.exit;

ExitFunction _exitFunction = _defaultExitFunction;

/// Exits the process.
///
/// Throws [AssertionError] if assertions are enabled and the dart:io exit
/// is still active when called. This may indicate exit was called in
/// a test without being configured correctly.
///
/// This is analogous to the `exit` function in `dart:io`, except that this
/// function may be set to a testing-friendly value by calling
/// [setExitFunctionForTests] (and then restored to its default implementation
/// with [restoreExitFunction]). The default implementation delegates to
/// `dart:io`.
ExitFunction get exit {
  assert(
    _exitFunction != io.exit || !_inUnitTest(),
    'io.exit was called with assertions active in a unit test',
  );
  return _exitFunction;
}

// Whether the tool is executing in a unit test.
bool _inUnitTest() {
  return Zone.current[#test.declarer] != null;
}

/// Sets the [exit] function to a function that throws an exception rather
/// than exiting the process; this is intended for testing purposes.
@visibleForTesting
void setExitFunctionForTests([ ExitFunction exitFunction ]) {
  _exitFunction = exitFunction ?? (int exitCode) {
    throw ProcessExit(exitCode, immediate: true);
  };
}

/// Restores the [exit] function to the `dart:io` implementation.
@visibleForTesting
void restoreExitFunction() {
  _exitFunction = _defaultExitFunction;
}

/// A portable version of [io.ProcessSignal].
///
/// Listening on signals that don't exist on the current platform is just a
/// no-op. This is in contrast to [io.ProcessSignal], where listening to
/// non-existent signals throws an exception.
///
/// This class does NOT implement io.ProcessSignal, because that class uses
/// private fields. This means it cannot be used with, e.g., [Process.killPid].
/// Alternative implementations of the relevant methods that take
/// [ProcessSignal] instances are available on this class (e.g. "send").
class ProcessSignal {
  @visibleForTesting
  const ProcessSignal(this._delegate);

  static const ProcessSignal SIGWINCH = _PosixProcessSignal._(io.ProcessSignal.sigwinch);
  static const ProcessSignal SIGTERM = _PosixProcessSignal._(io.ProcessSignal.sigterm);
  static const ProcessSignal SIGUSR1 = _PosixProcessSignal._(io.ProcessSignal.sigusr1);
  static const ProcessSignal SIGUSR2 = _PosixProcessSignal._(io.ProcessSignal.sigusr2);
  static const ProcessSignal SIGINT =  ProcessSignal(io.ProcessSignal.sigint);
  static const ProcessSignal SIGKILL =  ProcessSignal(io.ProcessSignal.sigkill);

  final io.ProcessSignal _delegate;

  Stream<ProcessSignal> watch() {
    return _delegate.watch().map<ProcessSignal>((io.ProcessSignal signal) => this);
  }

  /// Sends the signal to the given process (identified by pid).
  ///
  /// Returns true if the signal was delivered, false otherwise.
  ///
  /// On Windows, this can only be used with [ProcessSignal.SIGTERM], which
  /// terminates the process.
  ///
  /// This is implemented by sending the signal using [Process.killPid].
  bool send(int pid) {
    assert(!globals.platform.isWindows || this == ProcessSignal.SIGTERM);
    return io.Process.killPid(pid, _delegate);
  }

  @override
  String toString() => _delegate.toString();
}

/// A [ProcessSignal] that is only available on Posix platforms.
///
/// Listening to a [_PosixProcessSignal] is a no-op on Windows.
class _PosixProcessSignal extends ProcessSignal {

  const _PosixProcessSignal._(io.ProcessSignal wrappedSignal) : super(wrappedSignal);

  @override
  Stream<ProcessSignal> watch() {
    if (globals.platform.isWindows) {
      return const Stream<ProcessSignal>.empty();
    }
    return super.watch();
  }
}

/// A class that wraps stdout, stderr, and stdin, and exposes the allowed
/// operations.
///
/// In particular, there are three ways that writing to stdout and stderr
/// can fail. A call to stdout.write() can fail:
///   * by throwing a regular synchronous exception,
///   * by throwing an exception asynchronously, and
///   * by completing the Future stdout.done with an error.
///
/// This class enapsulates all three so that we don't have to worry about it
/// anywhere else.
class Stdio {
  Stdio();

  /// Tests can provide overrides to use instead of the stdout and stderr from
  /// dart:io.
  @visibleForTesting
  Stdio.test({
    @required io.Stdout stdout,
    @required io.IOSink stderr,
  }) : _stdoutOverride = stdout, _stderrOverride = stderr;

  io.Stdout _stdoutOverride;
  io.IOSink _stderrOverride;

  // These flags exist to remember when the done Futures on stdout and stderr
  // complete to avoid trying to write to a closed stream sink, which would
  // generate a [StateError].
  bool _stdoutDone = false;
  bool _stderrDone = false;

  Stream<List<int>> get stdin => io.stdin;

  @visibleForTesting
  io.Stdout get stdout {
    if (_stdout != null) {
      return _stdout;
    }
    _stdout = _stdoutOverride ?? io.stdout;
    _stdout.done.then(
      (void _) { _stdoutDone = true; },
      onError: (Object err, StackTrace st) { _stdoutDone = true; },
    );
    return _stdout;
  }
  io.Stdout _stdout;

  @visibleForTesting
  io.IOSink get stderr {
    if (_stderr != null) {
      return _stderr;
    }
    _stderr = _stderrOverride ?? io.stderr;
    _stderr.done.then(
      (void _) { _stderrDone = true; },
      onError: (Object err, StackTrace st) { _stderrDone = true; },
    );
    return _stderr;
  }
  io.IOSink _stderr;

  bool get hasTerminal => io.stdout.hasTerminal;

  static bool _stdinHasTerminal;

  /// Determines whether there is a terminal attached.
  ///
  /// [io.Stdin.hasTerminal] only covers a subset of cases. In this check the
  /// echoMode is toggled on and off to catch cases where the tool running in
  /// a docker container thinks there is an attached terminal. This can cause
  /// runtime errors such as "inappropriate ioctl for device" if not handled.
  bool get stdinHasTerminal {
    if (_stdinHasTerminal != null) {
      return _stdinHasTerminal;
    }
    if (stdin is! io.Stdin) {
      return _stdinHasTerminal = false;
    }
    final io.Stdin ioStdin = stdin as io.Stdin;
    if (!ioStdin.hasTerminal) {
      return _stdinHasTerminal = false;
    }
    try {
      final bool currentEchoMode = ioStdin.echoMode;
      ioStdin.echoMode = !currentEchoMode;
      ioStdin.echoMode = currentEchoMode;
    } on io.StdinException {
      return _stdinHasTerminal = false;
    }
    return _stdinHasTerminal = true;
  }

  int get terminalColumns => hasTerminal ? stdout.terminalColumns : null;
  int get terminalLines => hasTerminal ? stdout.terminalLines : null;
  bool get supportsAnsiEscapes => hasTerminal && stdout.supportsAnsiEscapes;

  /// Writes [message] to [stderr], falling back on [fallback] if the write
  /// throws any exception. The default fallback calls [print] on [message].
  void stderrWrite(
    String message, {
    void Function(String, dynamic, StackTrace) fallback,
  }) {
    if (!_stderrDone) {
      _stdioWrite(stderr, message, fallback: fallback);
      return;
    }
    fallback == null ? print(message) : fallback(
      message,
      const io.StdoutException('stderr is done'),
      StackTrace.current,
    );
  }

  /// Writes [message] to [stdout], falling back on [fallback] if the write
  /// throws any exception. The default fallback calls [print] on [message].
  void stdoutWrite(
    String message, {
    void Function(String, dynamic, StackTrace) fallback,
  }) {
    if (!_stdoutDone) {
      _stdioWrite(stdout, message, fallback: fallback);
      return;
    }
    fallback == null ? print(message) : fallback(
      message,
      const io.StdoutException('stdout is done'),
      StackTrace.current,
    );
  }

  // Helper for [stderrWrite] and [stdoutWrite].
  void _stdioWrite(io.IOSink sink, String message, {
    void Function(String, dynamic, StackTrace) fallback,
  }) {
    asyncGuard<void>(() async {
      sink.write(message);
    }, onError: (Object error, StackTrace stackTrace) {
      if (fallback == null) {
        print(message);
      } else {
        fallback(message, error, stackTrace);
      }
    });
  }

  /// Adds [stream] to [stdout].
  Future<void> addStdoutStream(Stream<List<int>> stream) => stdout.addStream(stream);

  /// Adds [srtream] to [stderr].
  Future<void> addStderrStream(Stream<List<int>> stream) => stderr.addStream(stream);
}

// TODO(zra): Move pid and writePidFile into `ProcessInfo`.
void writePidFile(String pidFile) {
  if (pidFile != null) {
    // Write our pid to the file.
    globals.fs.file(pidFile).writeAsStringSync(io.pid.toString());
  }
}

/// An overridable version of io.ProcessInfo.
abstract class ProcessInfo {
  factory ProcessInfo() => _DefaultProcessInfo();

  static ProcessInfo get instance => context.get<ProcessInfo>();

  int get currentRss;

  int get maxRss;
}

ProcessInfo get processInfo => ProcessInfo.instance;

/// The default implementation of [ProcessInfo], which uses [io.ProcessInfo].
class _DefaultProcessInfo implements ProcessInfo {
  @override
  int get currentRss => io.ProcessInfo.currentRss;

  @override
  int get maxRss => io.ProcessInfo.maxRss;
}

/// The return type for [listNetworkInterfaces].
class NetworkInterface implements io.NetworkInterface {
  NetworkInterface(this._delegate);

  final io.NetworkInterface _delegate;

  @override
  List<io.InternetAddress> get addresses => _delegate.addresses;

  @override
  int get index => _delegate.index;

  @override
  String get name => _delegate.name;

  @override
  String toString() => "NetworkInterface('$name', $addresses)";
}

typedef NetworkInterfaceLister = Future<List<NetworkInterface>> Function({
  bool includeLoopback,
  bool includeLinkLocal,
  io.InternetAddressType type,
});

NetworkInterfaceLister _networkInterfaceListerOverride;

// Tests can set up a non-default network interface lister.
@visibleForTesting
void setNetworkInterfaceLister(NetworkInterfaceLister lister) {
  _networkInterfaceListerOverride = lister;
}

@visibleForTesting
void resetNetworkInterfaceLister() {
  _networkInterfaceListerOverride = null;
}

/// This calls [NetworkInterface.list] from `dart:io` unless it is overridden by
/// [setNetworkInterfaceLister] for a test. If it is overridden for a test,
/// it should be reset with [resetNetworkInterfaceLister].
Future<List<NetworkInterface>> listNetworkInterfaces({
  bool includeLoopback = false,
  bool includeLinkLocal = false,
  io.InternetAddressType type = io.InternetAddressType.any,
}) async {
  if (_networkInterfaceListerOverride != null) {
    return _networkInterfaceListerOverride(
      includeLoopback: includeLoopback,
      includeLinkLocal: includeLinkLocal,
      type: type,
    );
  }
  final List<io.NetworkInterface> interfaces = await io.NetworkInterface.list(
    includeLoopback: includeLoopback,
    includeLinkLocal: includeLinkLocal,
    type: type,
  );
  return interfaces.map(
    (io.NetworkInterface interface) => NetworkInterface(interface),
  ).toList();
}
