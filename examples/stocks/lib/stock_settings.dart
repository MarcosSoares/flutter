// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'stock_types.dart';

class StockSettings extends StatefulWidget {
  const StockSettings(this.configuration, this.updater);

  final StockConfiguration configuration;
  final ValueChanged<StockConfiguration> updater;

  @override
  StockSettingsState createState() => new StockSettingsState();
}

class StockSettingsState extends State<StockSettings> {
  void _handleOptimismChanged(bool value) {
    value ??= false;
    sendUpdates(widget.configuration.copyWith(stockMode: value ? StockMode.optimistic : StockMode.pessimistic));
  }

  void _handleBackupChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(backupMode: value ? BackupMode.enabled : BackupMode.disabled));
  }

  void _handleShowGridChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(debugShowGrid: value));
  }

  void _handleShowSizesChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(debugShowSizes: value));
  }

  void _handleShowBaselinesChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(debugShowBaselines: value));
  }

  void _handleShowLayersChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(debugShowLayers: value));
  }

  void _handleShowPointersChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(debugShowPointers: value));
  }

  void _handleShowRainbowChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(debugShowRainbow: value));
  }


  void _handleShowPerformanceOverlayChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(showPerformanceOverlay: value));
  }

  void _handleShowSemanticsDebuggerChanged(bool value) {
    sendUpdates(widget.configuration.copyWith(showSemanticsDebugger: value));
  }

  void _confirmOptimismChange() {
    switch (widget.configuration.stockMode) {
      case StockMode.optimistic:
        _handleOptimismChanged(false);
        break;
      case StockMode.pessimistic:
        showDialog<bool>(
          context: context,
          child: new AlertDialog(
            title: new Text("Change mode?"),
            content: new Text("Optimistic mode means everything is awesome. Are you sure you can handle that?"),
            actions: <Widget>[
              new FlatButton(
                child: new Text('NO THANKS'),
                onPressed: () {
                  Navigator.pop(context, false);
                }
              ),
              new FlatButton(
                child: new Text('AGREE'),
                onPressed: () {
                  Navigator.pop(context, true);
                }
              ),
            ]
          )
        ).then<Null>(_handleOptimismChanged);
        break;
    }
  }

  void sendUpdates(StockConfiguration value) {
    if (widget.updater != null)
      widget.updater(value);
  }

  Widget buildAppBar(BuildContext context) {
    return new AppBar(
      title: new Text('Settings')
    );
  }

  Widget buildSettingsPane(BuildContext context) {
    final List<Widget> rows = <Widget>[
      new ListTile(
        leading: new Icon(Icons.thumb_up),
        title: new Text('Everything is awesome'),
        onTap: _confirmOptimismChange,
        trailing: new Checkbox(
          value: widget.configuration.stockMode == StockMode.optimistic,
          onChanged: (bool value) => _confirmOptimismChange(),
        ),
      ),
      new ListTile(
        leading: new Icon(Icons.backup),
        title: new Text('Back up stock list to the cloud'),
        onTap: () { _handleBackupChanged(!(widget.configuration.backupMode == BackupMode.enabled)); },
        trailing: new Switch(
          value: widget.configuration.backupMode == BackupMode.enabled,
          onChanged: _handleBackupChanged,
        ),
      ),
      new ListTile(
        leading: new Icon(Icons.picture_in_picture),
        title: new Text('Show rendering performance overlay'),
        onTap: () { _handleShowPerformanceOverlayChanged(!widget.configuration.showPerformanceOverlay); },
        trailing: new Switch(
          value: widget.configuration.showPerformanceOverlay,
          onChanged: _handleShowPerformanceOverlayChanged,
        ),
      ),
      new ListTile(
        leading: new Icon(Icons.accessibility),
        title: new Text('Show semantics overlay'),
        onTap: () { _handleShowSemanticsDebuggerChanged(!widget.configuration.showSemanticsDebugger); },
        trailing: new Switch(
          value: widget.configuration.showSemanticsDebugger,
          onChanged: _handleShowSemanticsDebuggerChanged,
        ),
      ),
    ];
    assert(() {
      // material grid and size construction lines are only available in checked mode
      rows.addAll(<Widget>[
        new ListTile(
          leading: new Icon(Icons.border_clear),
          title: new Text('Show material grid (for debugging)'),
          onTap: () { _handleShowGridChanged(!widget.configuration.debugShowGrid); },
          trailing: new Switch(
            value: widget.configuration.debugShowGrid,
            onChanged: _handleShowGridChanged,
          ),
        ),
        new ListTile(
          leading: new Icon(Icons.border_all),
          title: new Text('Show construction lines (for debugging)'),
          onTap: () { _handleShowSizesChanged(!widget.configuration.debugShowSizes); },
          trailing: new Switch(
            value: widget.configuration.debugShowSizes,
            onChanged: _handleShowSizesChanged,
          ),
        ),
        new ListTile(
          leading: new Icon(Icons.format_color_text),
          title: new Text('Show baselines (for debugging)'),
          onTap: () { _handleShowBaselinesChanged(!widget.configuration.debugShowBaselines); },
          trailing: new Switch(
            value: widget.configuration.debugShowBaselines,
            onChanged: _handleShowBaselinesChanged,
          ),
        ),
        new ListTile(
          leading: new Icon(Icons.filter_none),
          title: new Text('Show layer boundaries (for debugging)'),
          onTap: () { _handleShowLayersChanged(!widget.configuration.debugShowLayers); },
          trailing: new Switch(
            value: widget.configuration.debugShowLayers,
            onChanged: _handleShowLayersChanged,
          ),
        ),
        new ListTile(
          leading: new Icon(Icons.mouse),
          title: new Text('Show pointer hit-testing (for debugging)'),
          onTap: () { _handleShowPointersChanged(!widget.configuration.debugShowPointers); },
          trailing: new Switch(
            value: widget.configuration.debugShowPointers,
            onChanged: _handleShowPointersChanged,
          ),
        ),
        new ListTile(
          leading: new Icon(Icons.gradient),
          title: new Text('Show repaint rainbow (for debugging)'),
          onTap: () { _handleShowRainbowChanged(!widget.configuration.debugShowRainbow); },
          trailing: new Switch(
            value: widget.configuration.debugShowRainbow,
            onChanged: _handleShowRainbowChanged,
          ),
        ),
      ]);
      return true;
    });
    return new ListView(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: buildAppBar(context),
      body: buildSettingsPane(context)
    );
  }
}
