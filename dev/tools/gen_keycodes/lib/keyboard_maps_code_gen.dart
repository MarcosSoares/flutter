// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

import 'base_code_gen.dart';
import 'logical_key_data.dart';
import 'physical_key_data.dart';
import 'utils.dart';

bool _isLetter(String? char) {
  if (char == null)
    return false;
  const int charUpperA = 0x41;
  const int charUpperZ = 0x5A;
  const int charLowerA = 0x61;
  const int charLowerZ = 0x7A;
  assert(char.length == 1);
  final int charCode = char.codeUnitAt(0);
  return (charCode >= charUpperA && charCode <= charUpperZ)
      || (charCode >= charLowerA && charCode <= charLowerZ);
}

/// Generates the keyboard_maps.dart files, based on the information in the key
/// data structure given to it.
class KeyboardMapsCodeGenerator extends BaseCodeGenerator {
  KeyboardMapsCodeGenerator(PhysicalKeyData keyData, LogicalKeyData logicalData)
    : super(keyData, logicalData);

  List<PhysicalKeyEntry> get _numpadKeyData {
    return keyData.data.values.where((PhysicalKeyEntry entry) {
      return entry.constantName.startsWith('numpad') && LogicalKeyData.printable.containsKey(entry.name);
    }).toList();
  }

  List<PhysicalKeyEntry> get _functionKeyData {
    final RegExp functionKeyRe = RegExp(r'^f[0-9]+$');
    return keyData.data.values.where((PhysicalKeyEntry entry) {
      return functionKeyRe.hasMatch(entry.constantName);
    }).toList();
  }

  List<LogicalKeyEntry> get _numpadLogicalKeyData {
    return logicalData.data.values.where((LogicalKeyEntry entry) {
      return entry.constantName.startsWith('numpad') && LogicalKeyData.printable.containsKey(entry.name);
    }).toList();
  }

  /// This generates the map of GLFW number pad key codes to logical keys.
  String get _glfwNumpadMap {
    final StringBuffer glfwNumpadMap = StringBuffer();
    for (final PhysicalKeyEntry entry in _numpadKeyData) {
      for (final int code in entry.glfwKeyCodes) {
        glfwNumpadMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return glfwNumpadMap.toString().trimRight();
  }

  /// This generates the map of GLFW key codes to logical keys.
  String get _glfwKeyCodeMap {
    final StringBuffer glfwKeyCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      for (final int code in entry.glfwKeyCodes) {
        glfwKeyCodeMap.writeln('  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return glfwKeyCodeMap.toString().trimRight();
  }

  /// This generates the map of GTK number pad key codes to logical keys.
  String get _gtkNumpadMap {
    final OutputLines<int> lines = OutputLines<int>('GTK numpad map');
    for (final LogicalKeyEntry entry in _numpadLogicalKeyData) {
      for (final int code in entry.gtkValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of GTK key codes to logical keys.
  String get _gtkKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('GTK key code map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      for (final int code in entry.gtkValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of XKB USB HID codes to physical keys.
  String get _xkbScanCodeMap {
    final StringBuffer xkbScanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.xKbScanCode != null) {
        xkbScanCodeMap.writeln('  ${toHex(entry.xKbScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return xkbScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Android key codes to logical keys.
  String get _androidKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('Android key code map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      for (final int code in entry.androidValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of Android number pad key codes to logical keys.
  String get _androidNumpadMap {
    final OutputLines<int> lines = OutputLines<int>('Android numpad map');
    for (final LogicalKeyEntry entry in _numpadLogicalKeyData) {
      for (final int code in entry.androidValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of Android scan codes to physical keys.
  String get _androidScanCodeMap {
    final StringBuffer androidScanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.androidScanCodes != null) {
        for (final int code in entry.androidScanCodes) {
          androidScanCodeMap.writeln('  $code: PhysicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return androidScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Windows scan codes to physical keys.
  String get _windowsScanCodeMap {
    final StringBuffer windowsScanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.windowsScanCode != null) {
        windowsScanCodeMap.writeln('  ${toHex(entry.windowsScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return windowsScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Windows number pad key codes to logical keys.
  String get _windowsNumpadMap {
    final OutputLines<int> lines = OutputLines<int>('Windows numpad map');
    for (final LogicalKeyEntry entry in _numpadLogicalKeyData) {
      for (final int code in entry.windowsValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of Windows key codes to logical keys.
  String get _windowsKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('Windows key code map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      // Letter keys on Windows are not recorded in logical_key_data.json,
      // because they are not used by the embedding. Add them manually.
      final List<int>? keyCodes = entry.windowsValues.isNotEmpty
        ? entry.windowsValues
        : (_isLetter(entry.keyLabel) ? <int>[entry.keyLabel!.toUpperCase().codeUnitAt(0)] : null);
      if (keyCodes != null) {
        for (final int code in keyCodes) {
          lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
        }
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of macOS key codes to physical keys.
  String get _macOsScanCodeMap {
    final StringBuffer macOsScanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.macOsScanCode != null) {
        macOsScanCodeMap.writeln('  ${toHex(entry.macOsScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return macOsScanCodeMap.toString().trimRight();
  }

  /// This generates the map of macOS number pad key codes to logical keys.
  String get _macOsNumpadMap {
    final StringBuffer macOsNumPadMap = StringBuffer();
    for (final PhysicalKeyEntry entry in _numpadKeyData) {
      if (entry.macOsScanCode != null) {
        macOsNumPadMap.writeln('  ${toHex(entry.macOsScanCode)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return macOsNumPadMap.toString().trimRight();
  }

  String get _macOsFunctionKeyMap {
    final StringBuffer macOsFunctionKeyMap = StringBuffer();
    for (final PhysicalKeyEntry entry in _functionKeyData) {
      if (entry.macOsScanCode != null) {
        macOsFunctionKeyMap.writeln('  ${toHex(entry.macOsScanCode)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return macOsFunctionKeyMap.toString().trimRight();
  }

  /// This generates the map of macOS key codes to physical keys.
  String get _macOsKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('MacOS key code map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      for (final int code in entry.macOsKeyCodeValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of iOS key codes to physical keys.
  String get _iosScanCodeMap {
    final OutputLines<int> lines = OutputLines<int>('iOS scancode map');
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.iosScanCode != null) {
        lines.add(entry.iosScanCode!, '  ${toHex(entry.iosScanCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of iOS number pad key codes to logical keys.
  String get _iosNumpadMap {
    final OutputLines<int> lines = OutputLines<int>('iOS numpad map');
    for (final PhysicalKeyEntry entry in _numpadKeyData) {
      if (entry.iosScanCode != null) {
        lines.add(entry.iosScanCode!,'  ${toHex(entry.iosScanCode)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of macOS key codes to physical keys.
  String get _iosKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('iOS key code map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      for (final int code in entry.iosKeyCodeValues) {
        lines.add(code, '  $code: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of Fuchsia key codes to logical keys.
  String get _fuchsiaKeyCodeMap {
    final OutputLines<int> lines = OutputLines<int>('Fuchsia key code map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      for (final int value in entry.fuchsiaValues) {
        lines.add(value, '  ${toHex(value)}: LogicalKeyboardKey.${entry.constantName},');
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of Fuchsia USB HID codes to physical keys.
  String get _fuchsiaHidCodeMap {
    final StringBuffer fuchsiaScanCodeMap = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.usbHidCode != null) {
        fuchsiaScanCodeMap.writeln('  ${toHex(entry.usbHidCode)}: PhysicalKeyboardKey.${entry.constantName},');
      }
    }
    return fuchsiaScanCodeMap.toString().trimRight();
  }

  /// This generates the map of Web KeyboardEvent codes to logical keys.
  String get _webLogicalKeyMap {
    final OutputLines<String> lines = OutputLines<String>('Web logical key map');
    for (final LogicalKeyEntry entry in logicalData.data.values) {
      for (final String name in entry.webNames) {
        lines.add(name, "  '$name': LogicalKeyboardKey.${entry.constantName},");
      }
    }
    return lines.sortedJoin().trimRight();
  }

  /// This generates the map of Web KeyboardEvent codes to physical keys.
  String get _webPhysicalKeyMap {
    final StringBuffer result = StringBuffer();
    for (final PhysicalKeyEntry entry in keyData.data.values) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': PhysicalKeyboardKey.${entry.constantName},");
      }
    }
    return result.toString().trimRight();
  }

  String get _webNumpadMap {
    final StringBuffer result = StringBuffer();
    for (final LogicalKeyEntry entry in _numpadLogicalKeyData) {
      if (entry.name != null) {
        result.writeln("  '${entry.name}': LogicalKeyboardKey.${entry.constantName},");
      }
    }
    return result.toString().trimRight();
  }

  /// This generates the map of Web number pad codes to logical keys.
  String get _webLocationMap {
    final String jsonRaw = File(path.join(dataRoot, 'web_logical_location_mapping.json')).readAsStringSync();
    final Map<String, List<String?>> locationMap = parseMapOfListOfNullableString(jsonRaw);
    final StringBuffer result = StringBuffer();
    locationMap.forEach((String key, List<String?> keyNames) {
      final String keyStrings = keyNames.map((String? keyName) {
        final String? constantName = logicalData.data[keyName]?.constantName;
        if (constantName == null && keyName != null) {
          print('Error: $keyName is not a valid key.');
          return 'null';
        }
        return constantName != null ? 'LogicalKeyboardKey.$constantName' : 'null';
      }).join(', ');
      result.writeln("  '$key': <LogicalKeyboardKey?>[$keyStrings],");
    });
    return result.toString().trimRight();
  }

  @override
  String get templatePath => path.join(dataRoot, 'keyboard_maps.tmpl');

  @override
  Map<String, String> mappings() {
    return <String, String>{
      'ANDROID_SCAN_CODE_MAP': _androidScanCodeMap,
      'ANDROID_KEY_CODE_MAP': _androidKeyCodeMap,
      'ANDROID_NUMPAD_MAP': _androidNumpadMap,
      'FUCHSIA_SCAN_CODE_MAP': _fuchsiaHidCodeMap,
      'FUCHSIA_KEY_CODE_MAP': _fuchsiaKeyCodeMap,
      'MACOS_SCAN_CODE_MAP': _macOsScanCodeMap,
      'MACOS_NUMPAD_MAP': _macOsNumpadMap,
      'MACOS_FUNCTION_KEY_MAP': _macOsFunctionKeyMap,
      'MACOS_KEY_CODE_MAP': _macOsKeyCodeMap,
      'IOS_SCAN_CODE_MAP': _iosScanCodeMap,
      'IOS_NUMPAD_MAP': _iosNumpadMap,
      'IOS_KEY_CODE_MAP': _iosKeyCodeMap,
      'GLFW_KEY_CODE_MAP': _glfwKeyCodeMap,
      'GLFW_NUMPAD_MAP': _glfwNumpadMap,
      'GTK_KEY_CODE_MAP': _gtkKeyCodeMap,
      'GTK_NUMPAD_MAP': _gtkNumpadMap,
      'XKB_SCAN_CODE_MAP': _xkbScanCodeMap,
      'WEB_LOGICAL_KEY_MAP': _webLogicalKeyMap,
      'WEB_PHYSICAL_KEY_MAP': _webPhysicalKeyMap,
      'WEB_NUMPAD_MAP': _webNumpadMap,
      'WEB_LOCATION_MAP': _webLocationMap,
      'WINDOWS_LOGICAL_KEY_MAP': _windowsKeyCodeMap,
      'WINDOWS_PHYSICAL_KEY_MAP': _windowsScanCodeMap,
      'WINDOWS_NUMPAD_MAP': _windowsNumpadMap,
    };
  }
}
