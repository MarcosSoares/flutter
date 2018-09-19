// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

typedef UpdateUrlFetcher = Future<String> Function();

class Updater extends StatefulWidget {
  const Updater({ @required this.updateUrlFetcher, this.child, Key key })
    : assert(updateUrlFetcher != null),
      super(key: key);

  final UpdateUrlFetcher updateUrlFetcher;
  final Widget child;

  @override
  State createState() => UpdaterState();
}

class UpdaterState extends State<Updater> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  static DateTime _lastUpdateCheck;
  Future<void> _checkForUpdates() async {
    // Only prompt once a day
    if (_lastUpdateCheck != null &&
        DateTime.now().difference(_lastUpdateCheck) < const Duration(days: 1)) {
      return null; // We already checked for updates recently
    }
    _lastUpdateCheck = DateTime.now();

    final String updateUrl = await widget.updateUrlFetcher();
    if (updateUrl != null) {
      final bool wantsUpdate = await showDialog<bool>(context: context, builder: _buildDialog);
      if (wantsUpdate != null && wantsUpdate)
        launch(updateUrl);
    }
  }

  Widget _buildDialog(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle dialogTextStyle =
        theme.textTheme.subhead.copyWith(color: theme.textTheme.caption.color);
    return AlertDialog(
      title: const Text('Update Flutter Gallery?'),
      content: Text('A newer version is available.', style: dialogTextStyle),
      actions: <Widget>[
        FlatButton(
          child: const Text('NO THANKS'),
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
        FlatButton(
          child: const Text('UPDATE'),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
