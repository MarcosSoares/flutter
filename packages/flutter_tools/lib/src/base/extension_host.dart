import 'dart:async';
import 'dart:isolate';

import 'package:flutter_tool_api/extension.dart';
import 'package:yaml/yaml.dart';

import '../convert.dart';
import '../globals.dart';
import 'file_system.dart';
import 'platform.dart';

/// Generates and caches a snapshot of the tool extension apis to apply.
class CrossIsolateShim {
  CrossIsolateShim() {
    // HARDCODED.
    const String path = '/Users/jonahwilliams/Documents/flutter/packages/flutter_tool_macos';
    final String manifestPath = fs.path.join(path, 'tool_api.yaml');
    name = 'flutter_tool_macos';
    final YamlMap manifest = loadYaml(fs.file(manifestPath).readAsStringSync());
    final String className = manifest['name'];
    final String relativefileUri = Uri.file(manifest['file']).toFilePath(windows: platform.isWindows);
    final String absolute = fs.path.join(path, 'lib', relativefileUri);
    final String entrypoint = '''
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_tool_api/extension.dart';

import '$absolute' as api;

final api.$className instance = api.$className();

void main(List<String> args, [SendPort sendPort]) {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  receivePort.listen((dynamic message) async {
    if (message is String) {
      final Map<String, Object> requestRaw = json.decode(message);
      final Request request = Request.fromJson(requestRaw);
      final Response response = await instance.handleMessage(request);
      sendPort.send(json.encode(response.toJson()));
    }
  });
}
''';
    final Directory directory = fs.systemTempDirectory.createTempSync('flutter_api');
    directory.createSync(recursive: true);
    final File sourceFile = directory.childFile('main.dart');
    sourceFile
      ..createSync()
      ..writeAsStringSync(entrypoint);
    final ReceivePort receivePort = ReceivePort();
    Isolate.spawnUri(fs.path.toUri('${sourceFile.path}'), <String>[], receivePort.sendPort)
      .then((Isolate isolate) {
        _isolate = isolate;
        _receivePort = receivePort;
        _receivePort.listen((dynamic data) {
          if (data is SendPort) {
            _sendPort = data;
            _doneLoading.complete();
          } else if (data is String) {
            final Response response = Response.fromJson(json.decode(data));
            if (_pending[response.id] != null) {
              _pending[response.id].complete(response);
            }
          }
        });
      }, onError: (dynamic error) {
         printError('$error');
      });
  }

  final Completer<void> _doneLoading = Completer();
  String name;
  Isolate _isolate;
  ReceivePort _receivePort;
  SendPort _sendPort;
  final Map<int, Completer<Response>> _pending = <int, Completer<Response>>{};

  Future<Response> handleMessage(Request request) async {
    await _doneLoading.future;
    _pending[request.id] = Completer<Response>();
    _sendPort.send(json.encode(request.toJson()));
    return _pending[request.id].future;
  }
}

/// This is a temporary class for running extensions in the same isolate.
class SharedIsolateExtensions {
  SharedIsolateExtensions(this.extensions, this.crossIsolateShims);

  final List<ToolExtension> extensions;
  final List<CrossIsolateShim> crossIsolateShims;
  int _nextId = 0;

  /// Send a request to every active extension.
  Future<List<Response>> sendRequestAll(String method,
      {Map<String, Object> arguments = const <String, Object>{}}) async {
    final int id = _nextId;
    _nextId += 1;
    final Request request = Request(id, method, arguments);
    final List<Future<Response>> pendingResponses = <Future<Response>>[];
    for (ToolExtension extension in extensions) {
      pendingResponses.add(extension.handleMessage(request));
    }
    for (CrossIsolateShim shim in crossIsolateShims) {
      pendingResponses.add(shim.handleMessage(request));
    }
    return Future.wait(pendingResponses);
  }

  /// Send a request to a single named extension.
  Future<Response> sendRequest(String extensionName, String method,
      {Map<String, Object> arguments = const <String, Object>{}}) async {
    final int id = _nextId;
    _nextId += 1;
    final Request request = Request(id, method, arguments);
    final ToolExtension extension = extensions
        .firstWhere((ToolExtension extension) => extension.name == extensionName, orElse: () => null);
    if (extension == null) {
      final CrossIsolateShim shim = crossIsolateShims
        .firstWhere((CrossIsolateShim shim) => shim.name == extensionName, orElse: () => null);
      return shim.handleMessage(request);
    }
    return extension.handleMessage(request);
  }
}
