// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Flutter code sample for CupertinoActivityIndicator

import 'package:flutter/cupertino.dart';

void main() => runApp(const CupertinoIndicatorApp());

class CupertinoIndicatorApp extends StatelessWidget {
  const CupertinoIndicatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: CupertinoIndicatorExample(),
    );
  }
}

class CupertinoIndicatorExample extends StatelessWidget {
  const CupertinoIndicatorExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('CupertinoActivityIndicator Sample'),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                // Cupertino activity indicator with default properties.
                CupertinoActivityIndicator(),
                SizedBox(height: 10),
                Text('Default'),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                // Cupertino activity indicator with custom radius and color.
                CupertinoActivityIndicator(radius: 20.0, color: CupertinoColors.activeBlue),
                SizedBox(height: 10),
                Text(
                  'radius: 20.0\ncolor: CupertinoColors.activeBlue',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[
                // Cupertino activity indicator with custom radius and disabled animation.
                CupertinoActivityIndicator(radius: 20.0, animating: false),
                SizedBox(height: 10),
                Text(
                  'radius: 20.0\nanimating: false',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      )
    );
  }
}
