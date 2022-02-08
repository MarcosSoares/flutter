// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Flutter code sample for ThemeExtension

import 'package:flutter/material.dart';

@immutable
class MyColors implements ThemeExtension {
  const MyColors({
    this.blue,
    this.red,
  });

  final Color? blue;
  final Color? red;

  @override
  MyColors copyWith({Color? red, Color? blue}) {
    return MyColors(
      blue: blue ?? this.blue,
      red: red ?? this.red,
    );
  }

  @override
  MyColors lerp(ThemeExtension? other, double t) {
    if (other is MyColors) {
      return MyColors(
        blue: Color.lerp(blue, other.blue, t),
        red: Color.lerp(red, other.red, t),
      );
    } else {
      return this;
    }
  }

  // Optional
  @override
  bool operator ==(Object other) {
    return other is MyColors &&
        other.blue == blue &&
        other.red == red;
  }

  // Optional
  @override
  int get hashCode {
    return hashList(<Object?>[
      blue,
      red,
    ]);
  }
}

extension on ThemeData {
  MyColors get myColors => themeExtension! as MyColors;
}


void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static const String _title = 'Flutter Code Sample';

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isLightTheme = true;


  void toggleTheme() => setState(() => isLightTheme = !isLightTheme);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: MyApp._title,
      theme: ThemeData.light().copyWith(
        themeExtension: const MyColors(
          blue: Color(0xFF1E88E5),
          red: Color(0xFFE53935),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        themeExtension: const MyColors(
          blue: Color(0xFF90CAF9),
          red: Color(0xFFEF9A9A),
        ),
      ),
      themeMode: isLightTheme ? ThemeMode.light : ThemeMode.dark,
      home: MyStatelessWidget(
        isLightTheme: isLightTheme,
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class MyStatelessWidget extends StatelessWidget {
  const MyStatelessWidget({
    Key? key,
    required this.isLightTheme,
    required this.toggleTheme,
  }) : super(key: key);

  final bool isLightTheme;
  final void Function() toggleTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(width: 100, height: 100, color: Theme.of(context).myColors.blue),
            const SizedBox(width: 10),
            Container(width: 100, height: 100, color: Theme.of(context).myColors.red),
            const SizedBox(width: 50),
            IconButton(
              icon: Icon(isLightTheme ? Icons.nightlight : Icons.wb_sunny),
              onPressed: toggleTheme,
            ),
          ],
        )
      ),
    );
  }
}
