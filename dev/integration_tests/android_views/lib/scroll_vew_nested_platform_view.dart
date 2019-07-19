// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'page.dart';
import 'simple_platform_view.dart';

class ScrollViewNestedPlatformView extends Page {
  const ScrollViewNestedPlatformView()
      : super('ScrollViewNestedPlatformView Tests',
            const ValueKey<String>('ScrollViewNestedPlatformViewListTile'));

  @override
  Widget build(BuildContext context) {
    return ScrollViewNestedPlatformViewBody();
  }
}


class ScrollViewNestedPlatformViewBody extends StatefulWidget {

  const ScrollViewNestedPlatformViewBody():super(key: const ValueKey<String>('ScrollViewNestedPlatformView'));

  @override
  State createState() => ScrollViewNestedPlatformViewBodyState();
}

class ScrollViewNestedPlatformViewBodyState extends State<ScrollViewNestedPlatformViewBody> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10.0),
            topRight: Radius.circular(10.0),
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 100.0),
              child: SimplePlatformView(key: const ValueKey<String>('PlatformView'), onPlatformViewCreated: _onPlatformViewCreated,),
            ),
          ),
      );
  }

  void _onPlatformViewCreated(int id) {
    driverDataHandler.handlerCompleter.complete(handleDriverMessage);
  }

  Future<String> handleDriverMessage(String message) async {
    switch (message) {
      case 'pop':
        Navigator.of(context).pop(true);
        return 'success';
    }
    return 'unknown message: "$message"';
  }
}