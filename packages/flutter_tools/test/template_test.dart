// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/template.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:mockito/mockito.dart';

import 'src/common.dart';
import 'src/testbed.dart';

void main() {
  Testbed testbed;

  setUp(() {
    testbed = Testbed();
  });

  test('Template.render throws ToolExit when FileSystem exception is raised', () => testbed.run(() {
    final Template template = Template(globals.fs.directory('examples'), globals.fs.currentDirectory, null, fileSystem: globals.fs);
    final MockDirectory mockDirectory = MockDirectory();
    when(mockDirectory.createSync(recursive: true)).thenThrow(const FileSystemException());

    expect(() => template.render(mockDirectory, <String, Object>{}),
        throwsToolExit());
  }));

  test('Template.render replaces .img.tmpl files with files from the image source', () => testbed.run(() {
    final MemoryFileSystem fileSystem = MemoryFileSystem();
    final Directory templateDir = fileSystem.directory('templates');
    final Directory imageSourceDir = fileSystem.directory('template_images');
    final Directory destination = fileSystem.directory('target');
    const String imageName = 'some_image.png';
    templateDir.childFile('$imageName.img.tmpl').createSync(recursive: true);
    final File sourceImage = imageSourceDir.childFile(imageName);
    sourceImage.createSync(recursive: true);
    sourceImage.writeAsStringSync('Ceci n\'est pas une pipe');

    final Template template = Template(templateDir, templateDir, imageSourceDir, fileSystem: fileSystem);
    template.render(destination, <String, Object>{});

    final File destinationImage = destination.childFile(imageName);
    expect(destinationImage.existsSync(), true);
    expect(destinationImage.readAsBytesSync(), equals(sourceImage.readAsBytesSync()));
  }));
}

class MockDirectory extends Mock implements Directory {}
