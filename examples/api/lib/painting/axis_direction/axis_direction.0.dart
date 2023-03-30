// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Flutter code sample for [AxisDirection]s.

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String _title = 'Flutter Code Sample';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: _title,
      home: MyWidget(),
    );
  }
}

class MyWidget extends StatefulWidget {
  const MyWidget({ super.key });

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final List<String> alphabet = <String>[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];
  final Widget spacer = const SizedBox.square(dimension: 10);
  Axis axis = Axis.vertical;
  bool reverse = false;

  AxisDirection _getAxisDirection() {
    switch (axis) {
      case Axis.vertical:
        return reverse ? AxisDirection.up : AxisDirection.down;
      case Axis.horizontal:
        return reverse ? AxisDirection.left : AxisDirection.right;
    }
  }

  Widget _getArrows() {
    final Widget arrow;
    switch(_getAxisDirection()) {
      case AxisDirection.up:
        arrow = const Icon(Icons.arrow_upward_rounded);
      case AxisDirection.down:
        arrow = const Icon(Icons.arrow_downward_rounded);
      case AxisDirection.left:
        arrow = const Icon(Icons.arrow_back_rounded);
      case AxisDirection.right:
        arrow = const Icon(Icons.arrow_forward_rounded);
    }

    switch(axis) {
      case Axis.vertical:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[ arrow, arrow ]
        );
      case Axis.horizontal:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[ arrow, arrow ]
        );
    }
  }

  void _onAxisDirectionChanged(AxisDirection? axisDirection) {
    switch(axisDirection) {
      case AxisDirection.up:
        reverse = true;
        axis = Axis.vertical;
      case AxisDirection.down:
        reverse = false;
        axis = Axis.vertical;
      case AxisDirection.left:
        reverse = true;
        axis = Axis.horizontal;
      case AxisDirection.right:
        reverse = false;
        axis = Axis.horizontal;
      case null:
    }
    setState((){
      // Respond to change in axis direction.
    });
  }

  Widget _getLeading() {
    return Container(
      color: Colors.blue[100],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(axis.toString()),
            spacer,
            Text(_getAxisDirection().toString()),
            spacer,
            const Text('GrowthDirection.forward'),
            spacer,
            _getArrows(),
          ],
        ),
      ),
    );
  }

  Widget _getRadioRow() {
    return DefaultTextStyle(
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      child: RadioTheme(
        data: RadioThemeData(
          fillColor: MaterialStateProperty.all<Color>(Colors.white),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Radio<AxisDirection>(
                value: AxisDirection.up,
                groupValue: _getAxisDirection(),
                onChanged: _onAxisDirectionChanged,
              ),
              const Text('up'),
              spacer,
              Radio<AxisDirection>(
                value: AxisDirection.down,
                groupValue: _getAxisDirection(),
                onChanged: _onAxisDirectionChanged,
              ),
              const Text('down'),
              spacer,
              Radio<AxisDirection>(
                value: AxisDirection.left,
                groupValue: _getAxisDirection(),
                onChanged: _onAxisDirectionChanged,
              ),
              const Text('left'),
              spacer,
              Radio<AxisDirection>(
                value: AxisDirection.right,
                groupValue: _getAxisDirection(),
                onChanged: _onAxisDirectionChanged,
              ),
              const Text('right'),
              spacer,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AxisDirection'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _getRadioRow(),
          ),
        ),
      ),
      body: CustomScrollView(
        reverse: reverse,
        scrollDirection: axis,
        slivers: <Widget>[
          SliverList.builder(
            itemCount: 27,
            itemBuilder: (BuildContext context, int index) {
              late Widget child;
              if (index == 0) {
                child = _getLeading();
              } else {
                child = Container(
                  color: index.isEven ? Colors.amber[100] : Colors.amberAccent,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: Text(alphabet[index - 1])),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: child,
              );
            }
          ),
        ],
      ),
    );
  }
}
