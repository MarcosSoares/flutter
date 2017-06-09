// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'bottom_tab_bar.dart';
import 'nav_bar.dart';

/// Implements a basic iOS application's layout and behavior structure.
///
/// The scaffold lays out the navigation bar on top, the tab bar at the bottom
/// and tabbed or untabbed content between or behind the bars.
///
/// For tabbed scaffolds, the tab's active item and the actively showing tab
/// in the content area are automatically connected.
// TODO(xster): describe navigator handlings.
// TODO(xster): add an example.
class CupertinoScaffold extends StatefulWidget {
  /// Construct a [CupertinoScaffold] without tabs.
  // TODO(xster): document that page transitions will happen behind the navigation
  // bar.
  const CupertinoScaffold({
    Key key,
    this.navigationBar,
    @required this.child,
  })
      : tabBar = null,
        rootTabPageBuilder = null,
        super(key: key);

  /// Construct a [CupertinoScaffold] with tabs.
  ///
  /// A [tabBar] and a [rootTabPageBuilder] are required. The [CupertinoScaffold]
  /// will automatically listen to the provide [CupertinoTabBar]'s tap callbacks
  /// to change the active tab.
  ///
  /// Tabs' contents are built with the provided [rootTabPageBuilder] at the active
  /// tab index. [rootTabPageBuilder] must be able to build the same number of
  /// pages as the [tabBar.items.length].
  const CupertinoScaffold.tabbed({
    Key key,
    this.navigationBar,
    @required this.tabBar,
    @required this.rootTabPageBuilder,
  })
      : assert(tabBar != null),
        assert(rootTabPageBuilder != null),
        child = null,
        super(key: key);

  /// The [navigationBar], typically a [CupertinoNavigationBar], is drawn at the
  /// top of the screen.
  ///
  /// If translucent, the main content may slide behind it.
  /// Otherwise, the main content's top margin will be offset by its height.
  // TODO(xster): document its page transition animation when ready
  final PreferredSizeWidget navigationBar;

  /// The [tabBar] is a [CupertinoTabBar] drawn at the bottom of the screen
  /// that lets the user switch between different tabs in the main content area
  /// when present.
  ///
  /// When provided, [CupertinoTabBar.currentIndex] will be ignored and will
  /// be managed by the [CupertinoScaffold] to show the currently selected page
  /// as the active item index. If [CupertinoTabBar.onTap] is provided, it will
  /// still be called. [CupertinoScaffold] automatically also listen to the
  /// [CupertinoTabBar]'s `onTap` to change the [CupertinoTabBar]'s `currentIndex`
  /// and change the actively displayed tab in [CupertinoScaffold]'s own
  /// main content area.
  ///
  /// If translucent, the main content may slide behind it.
  /// Otherwise, the main content's bottom margin will be offset by its height.
  final CupertinoTabBar tabBar;

  /// An [IndexedWidgetBuilder] that's called when tabs become active. Used
  /// when a tabbed scaffold is constructed via the [new CupertinoScaffold.tabbed]
  /// constructor.
  ///
  /// Content can slide under the [navigationBar] or the [tabBar] when they're
  /// translucent.
  final IndexedWidgetBuilder rootTabPageBuilder;

  /// Widget to show in the main content area when the scaffold is used without
  /// tabs.
  ///
  /// Content can slide under the [navigationBar] or the [tabBar] when they're
  /// translucent.
  final Widget child;

  @override
  _CupertinoScaffoldState createState() => new _CupertinoScaffoldState();
}

class _CupertinoScaffoldState extends State<CupertinoScaffold> {
  int _currentPage = 0;

  Widget _padMiddle(Widget middle) {
    double topPadding = MediaQuery
        .of(context)
        .padding
        .top;
    if (widget.navigationBar is CupertinoNavigationBar) {
      final CupertinoNavigationBar top = widget.navigationBar;
      if (top.opaque)
        topPadding += top.preferredSize.height;
    }

    double bottomPadding = 0.0;
    if (widget.tabBar?.opaque ?? false)
      bottomPadding = widget.tabBar.preferredSize.height;

    return new Padding(
      padding: new EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: middle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> stacked = <Widget>[];

    // The main content being at the bottom is added to the stack first.
    if (widget.child != null) {
      stacked.add(_padMiddle(widget.child));
    } else if (widget.rootTabPageBuilder != null) {
      stacked.add(_padMiddle(new _TabView(
        currentTabIndex: _currentPage,
        tabNumber: widget.tabBar.items.length,
        rootTabPageBuilder: widget.rootTabPageBuilder,
      )));
    }

    if (widget.navigationBar != null) {
      stacked.add(new Align(
        alignment: FractionalOffset.topCenter,
        child: widget.navigationBar,
      ));
    }

    if (widget.tabBar != null) {
      stacked.add(new Align(
        alignment: FractionalOffset.bottomCenter,
        child: widget.tabBar.copyWith(
            currentIndex: _currentPage,
            onTap: (int newIndex) {
              setState(() {
                _currentPage = newIndex;
              });
              // Chain the user's original callback after the automatic scaffold behavior.
              if (widget.tabBar.onTap != null)
                widget.tabBar.onTap(newIndex);
            }
        ),
      ));
    }

    return new Stack(
      children: stacked,
    );
  }
}

class _TabView extends StatefulWidget {
  _TabView({
    @required this.currentTabIndex,
    @required this.tabNumber,
    @required this.rootTabPageBuilder,
  }) : assert(currentTabIndex != null),
       assert(tabNumber != null && tabNumber > 0),
       assert(rootTabPageBuilder != null);

  final int currentTabIndex;
  final int tabNumber;
  final IndexedWidgetBuilder rootTabPageBuilder;

  @override
  _TabViewState createState() => new _TabViewState();
}

class _TabViewState extends State<_TabView> {
  List<Widget> tabs;

  @override
  void initState() {
    super.initState();
    tabs = new List<Widget>.filled(widget.tabNumber, new Container());
  }

  @override
  Widget build(BuildContext context) {
    return new CustomMultiChildLayout(
      delegate: new _TabViewLayout(activeTab: widget.currentTabIndex),
      children: new List<Widget>.generate(widget.tabNumber, (int index) {
        final bool active = index == widget.currentTabIndex;
        // If the tab is being shown re-build and cache it.
        if (active)
          tabs[index] = widget.rootTabPageBuilder(context, index);

        return new LayoutId(
          id: index,
          child: new Offstage(
            offstage: !active,
            child: new TickerMode(
              enabled: active,
              child: tabs[index],
            ),
          ),
        );
      }),
    );
  }
}

class _TabViewLayout extends MultiChildLayoutDelegate {
  _TabViewLayout({ @required this.activeTab }) : assert(activeTab != null);

  final int activeTab;

  @override
  void performLayout(Size size) {
    final BoxConstraints constraints = new BoxConstraints.loose(size);
    layoutChild(activeTab, constraints);

    positionChild(activeTab, Offset.zero);
  }

  @override
  bool shouldRelayout(_TabViewLayout oldDelegate) => activeTab != oldDelegate.activeTab;
}
