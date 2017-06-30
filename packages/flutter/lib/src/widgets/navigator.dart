// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'basic.dart';
import 'binding.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';
import 'overlay.dart';
import 'routes.dart';
import 'ticker_provider.dart';

/// An abstraction for an entry managed by a [BasicNavigator].
///
/// This class defines an abstract interface between the navigator and the
/// "routes" that are pushed on and popped off the navigator. Most routes have
/// visual affordances, which they place in the navigators [Overlay] using one
/// or more [OverlayEntry] objects.
///
/// See [Navigator] for more explanation of how to use a Route
/// with navigation, including code examples.
///
/// See [MaterialPageRoute] for a route that replaces the
/// entire screen with a platform-adaptive transition.
abstract class Route<T> {
  /// The navigator that the route is in, if any.  Deprecated, use navigatorState
  /// getter instead.
  @deprecated
  NavigatorState<BasicNavigator> get navigator => _navigatorState;

  /// The [NavigatorState] of the [BasicNavigator] that the route is in,
  /// if any.
  NavigatorState<BasicNavigator> get navigatorState => _navigatorState;
  NavigatorState<BasicNavigator> _navigatorState;

  /// The overlay entries for this route.
  List<OverlayEntry> get overlayEntries => const <OverlayEntry>[];

  /// A future that completes when this route is popped off the navigator.
  ///
  /// The future completes with the value given to [Navigator.pop], if any.
  Future<T> get popped => _popCompleter.future;
  final Completer<T> _popCompleter = new Completer<T>();

  /// Called when the route is inserted into the navigator.
  ///
  /// Use this to populate overlayEntries and add them to the overlay
  /// (accessible as navigator.overlay). (The reason the Route is responsible
  /// for doing this, rather than the Navigator, is that the Route will be
  /// responsible for _removing_ the entries and this way it's symmetric.)
  ///
  /// The overlay argument will be null if this is the first route inserted.
  @protected
  @mustCallSuper
  void install(OverlayEntry insertionPoint) { }

  /// Called after [install] when the route is pushed onto the navigator.
  ///
  /// The returned value resolves when the push transition is complete.
  @protected
  TickerFuture didPush() => new TickerFuture.complete();

  /// When this route is popped (see [Navigator.pop]) if the result isn't
  /// specified or if it's null, this value will be used instead.
  T get currentResult => null;

  /// Called after [install] when the route replaced another in the navigator.
  @protected
  @mustCallSuper
  void didReplace(Route<dynamic> oldRoute) { }

  /// Returns false if this route wants to veto a [Navigator.pop]. This method is
  /// called by [Navigator.maybePop].
  ///
  /// By default, routes veto a pop if they're the first route in the history
  /// (i.e., if [isFirst]). This behavior prevents the user from popping the
  /// first route off the history and being stranded at a blank screen.
  ///
  /// See also:
  ///
  /// * [Form], which provides a [Form.onWillPop] callback that uses this mechanism.
  Future<RoutePopDisposition> willPop() async {
    return isFirst ? RoutePopDisposition.bubble : RoutePopDisposition.pop;
  }

  /// A request was made to pop this route. If the route can handle it
  /// internally (e.g. because it has its own stack of internal state) then
  /// return false, otherwise return true. Returning false will prevent the
  /// default behavior of [NavigatorState.pop].
  ///
  /// When this function returns true, the navigator removes this route from
  /// the history but does not yet call [dispose]. Instead, it is the route's
  /// responsibility to call [NavigatorState.finalizeRoute], which will in turn
  /// call [dispose] on the route. This sequence lets the route perform an
  /// exit animation (or some other visual effect) after being popped but prior
  /// to being disposed.
  @protected
  @mustCallSuper
  bool didPop(T result) {
    didComplete(result);
    return true;
  }

  /// Whether calling [didPop] would return false.
  bool get willHandlePopInternally => false;

  /// The given route, which came after this one, has been popped off the
  /// navigator.
  @protected
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) { }

  /// This route's next route has changed to the given new route. This is called
  /// on a route whenever the next route changes for any reason, except for
  /// cases when [didPopNext] would be called, so long as it is in the history.
  /// `nextRoute` will be null if there's no next route.
  @protected
  @mustCallSuper
  void didChangeNext(Route<dynamic> nextRoute) { }

  /// This route's previous route has changed to the given new route. This is
  /// called on a route whenever the previous route changes for any reason, so
  /// long as it is in the history, except for immediately after the route has
  /// been pushed (in which wase [didPush] or [didReplace] will be called
  /// instead). `previousRoute` will be null if there's no previous route.
  @protected
  @mustCallSuper
  void didChangePrevious(Route<dynamic> previousRoute) { }

  /// The route was popped or is otherwise being removed somewhat gracefully.
  ///
  /// This is called by [didPop] and in response to [Navigator.pushReplacement].
  @protected
  @mustCallSuper
  void didComplete(T result) {
    _popCompleter.complete(result);
  }

  /// The route should remove its overlays and free any other resources.
  ///
  /// This route is no longer referenced by the navigator.
  @mustCallSuper
  @protected
  void dispose() {
    assert(() {
      if (navigatorState == null) {
        throw new FlutterError(
          '$runtimeType.dipose() called more than once.\n'
          'A given route cannot be disposed more than once.'
        );
      }
      return true;
    });
    _navigatorState = null;
  }

  /// If the route's transition can be popped via a user gesture (e.g. the iOS
  /// back gesture), this should return a controller object that can be used to
  /// control the transition animation's progress. Otherwise, it should return
  /// null.
  ///
  /// If attempts to dismiss this route might be vetoed, for example because
  /// a [WillPopCallback] was defined for the route, then it may make sense
  /// to disable the pop gesture. For example, the iOS back gesture is disabled
  /// when [ModalRoute.hasScopedWillPopCallback] is true.
  NavigationGestureController startPopGesture() => null;

  /// Whether this route is the top-most route on the navigator.
  ///
  /// If this is true, then [isActive] is also true.
  bool get isCurrent {
    return _navigatorState != null && _navigatorState._history.last == this;
  }

  /// Whether this route is the bottom-most route on the navigator.
  ///
  /// If this is true, then [Navigator.canPop] will return false if this route's
  /// [willHandlePopInternally] returns false.
  ///
  /// If [isFirst] and [isCurrent] are both true then this is the only route on
  /// the navigator (and [isActive] will also be true).
  bool get isFirst {
    return _navigatorState != null && _navigatorState._history.first == this;
  }

  /// Whether this route is on the navigator.
  ///
  /// If the route is not only active, but also the current route (the top-most
  /// route), then [isCurrent] will also be true. If it is the first route (the
  /// bottom-most route), then [isFirst] will also be true.
  ///
  /// If a later route is entirely opaque, then the route will be active but not
  /// rendered. It is even possible for the route to be active but for the stateful
  /// widgets within the route to not be instatiated. See [ModalRoute.maintainState].
  bool get isActive {
    return _navigatorState != null && _navigatorState._history.contains(this);
  }
}

/// Data that might be useful in constructing a [Route].
@immutable
class RouteSettings {
  /// Creates data used to construct routes.
  const RouteSettings({
    this.name,
    this.arguments,
    this.isInitialRoute: false,
  });

  /// Creates a copy of this route settings object with the given fields
  /// replaced with the new values.
  RouteSettings copyWith({
    String name,
    dynamic arguments,
    bool isInitialRoute,
  }) {
    return new RouteSettings(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      isInitialRoute: isInitialRoute ?? this.isInitialRoute,
    );
  }

  /// Optional name of the route (e.g., "/settings").
  ///
  /// If null, the route is anonymous.
  final String name;

  /// Optional arguments to pass to a [RouteFactory].
  final dynamic arguments;

  /// Whether this route is the very first route being pushed onto this [Navigator].
  ///
  /// The initial route typically skips any entrance transition to speed startup.
  final bool isInitialRoute;

  @override
  String toString() => '"$name"';
}

/// Creates a route for the given route settings.
///
/// Used by [Navigator.onGenerateRoute] and [Navigator.onUnknownRoute].
typedef Route<dynamic> RouteFactory(RouteSettings settings);

/// Signature for the [Navigator.popUntil] predicate argument.
typedef bool RoutePredicate(Route<dynamic> route);

/// An interface for observing the behavior of a [Navigator].
class NavigatorObserver {
  /// The navigator that the observer is observing, if any. Deprecated, use
  /// navigatorState getter instead.
  @deprecated
  NavigatorState<BasicNavigator> get navigator => _navigatorState;

  /// The [NavigatorState] of the [BasicNavigator] that the observer
  /// is observing, if any.
  NavigatorState<BasicNavigator> get navigatorState => _navigatorState;
  NavigatorState<BasicNavigator> _navigatorState;

  /// The [Navigator] pushed `route`.
  void didPush(Route<dynamic> route, Route<dynamic> previousRoute) { }

  /// The [Navigator] popped `route`.
  void didPop(Route<dynamic> route, Route<dynamic> previousRoute) { }

  /// The [Navigator] removed `route`.
  void didRemove(Route<dynamic> route, Route<dynamic> previousRoute) { }

  /// The [Navigator] is being controlled by a user gesture.
  ///
  /// Used for the iOS back gesture.
  void didStartUserGesture() { }

  /// User gesture is no longer controlling the [Navigator].
  void didStopUserGesture() { }
}

/// Interface describing an object returned by the [Route.startPopGesture]
/// method, allowing the route's transition animations to be controlled by a
/// drag or other user gesture.
abstract class NavigationGestureController {
  /// Configures the NavigationGestureController and tells the given [Navigator] that
  /// a gesture has started.
  NavigationGestureController(this._navigatorState)
    : assert(_navigatorState != null) {
    // Disable Hero transitions until the gesture is complete.
    _navigatorState.didStartUserGesture();
  }

  /// The state object for the navigator that this object is controlling.
  /// Deprecated: use the navigatorState accessor instead.
  @deprecated
  @protected
  NavigatorState<BasicNavigator> get navigator => _navigatorState;

  /// The state object for the navigator that this object is controlling.
  @protected
  NavigatorState<BasicNavigator> get navigatorState => _navigatorState;

  NavigatorState<BasicNavigator> _navigatorState;

  /// Release the resources used by this object. The object is no longer usable
  /// after this method is called.
  ///
  /// Must be called when the gesture is done.
  ///
  /// Calling this method notifies the navigator that the gesture has completed.
  @mustCallSuper
  void dispose() {
    _navigatorState.didStopUserGesture();
    _navigatorState = null;
  }

  /// The drag gesture has changed by [fractionalDelta]. The total range of the
  /// drag should be 0.0 to 1.0.
  void dragUpdate(double fractionalDelta);

  /// The drag gesture has ended with a horizontal motion of
  /// [fractionalVelocity] as a fraction of screen width per second.
  ///
  /// Returns true if the gesture will complete (i.e. a back gesture will
  /// result in a pop).
  bool dragEnd(double fractionalVelocity);
}

/// Abstract class that defines the state interface for a [BaseNavigator] subclass.
// This is complicated (and exists) because it has to support the old interface
// for NavigatorState.
abstract class NavigatorState<T extends BasicNavigator> extends State<T> with TickerProviderStateMixin {
  final GlobalKey<OverlayState> _overlayKey = new GlobalKey<OverlayState>();
  final List<Route<dynamic>> _history = <Route<dynamic>>[];
  final Set<Route<dynamic>> _poppedRoutes = new Set<Route<dynamic>>();

  /// The [FocusScopeNode] for the [FocusScope] that encloses the routes.
  final FocusScopeNode focusScopeNode = new FocusScopeNode();

  final List<OverlayEntry> _initialOverlayEntries = <OverlayEntry>[];

  @override
  void initState() {
    super.initState();
    for (NavigatorObserver observer in widget.observers) {
      assert(observer.navigatorState == null);
      observer._navigatorState = this;
    }
    _createInitialRoutes();
    for (Route<dynamic> route in _history)
      _initialOverlayEntries.addAll(route.overlayEntries);
  }

  /// Subclasses override this to populate the route stack before they are added
  /// to [_initialOverlayEntries] in [initState].
  void _createInitialRoutes() {}

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.observers != widget.observers) {
      for (NavigatorObserver observer in oldWidget.observers)
        observer._navigatorState = null;
      for (NavigatorObserver observer in widget.observers) {
        assert(observer.navigatorState == null);
        observer._navigatorState = this;
      }
    }
  }

  @override
  void dispose() {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    for (NavigatorObserver observer in widget.observers)
      observer._navigatorState = null;
    final List<Route<dynamic>> doomed = _poppedRoutes.toList()
      ..addAll(_history);
    for (Route<dynamic> route in doomed)
      route.dispose();
    _poppedRoutes.clear();
    _history.clear();
    focusScopeNode.detach();
    super.dispose();
    assert(() {
      _debugLocked = false;
      return true;
    });
  }

  /// The overlay this navigator uses for its visual presentation.
  OverlayState get overlay => _overlayKey.currentState;

  OverlayEntry get _currentOverlayEntry {
    for (Route<dynamic> route in _history.reversed) {
      if (route.overlayEntries.isNotEmpty)
        return route.overlayEntries.last;
    }
    return null;
  }

  bool _debugLocked = false; // used to prevent re-entrant calls to push, pop, and friends

  /// Adds the given route to the navigator's history, and transitions to it.
  ///
  /// The new route and the previous route (if any) are notified (see
  /// [Route.didPush] and [Route.didChangeNext]). If the [BasicNavigator] has any
  /// [BasicNavigator.observers], they will be notified as well (see
  /// [NavigatorObserver.didPush]).
  ///
  /// Ongoing gestures within the current route are canceled when a new route is
  /// pushed.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  Future<dynamic> push(Route<dynamic> route) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    assert(route != null);
    assert(route._navigatorState == null);
    setState(() {
      final Route<dynamic> oldRoute = _history.isNotEmpty ? _history.last : null;
      route._navigatorState = this;
      route.install(_currentOverlayEntry);
      _history.add(route);
      route.didPush();
      route.didChangeNext(null);
      if (oldRoute != null)
        oldRoute.didChangeNext(route);
      for (NavigatorObserver observer in widget.observers)
        observer.didPush(route, oldRoute);
    });
    assert(() {
      _debugLocked = false;
      return true;
    });
    _cancelActivePointers();
    return route.popped;
  }

  /// Replaces a route that is not currently visible with a new route.
  ///
  /// The new route and the route below the new route (if any) are notified
  /// (see [Route.didReplace] and [Route.didChangeNext]). The navigator observer
  /// is not notified. The old route is disposed (see [Route.dispose]).
  ///
  /// This can be useful in combination with [removeRouteBelow] when building a
  /// non-linear user experience.
  void replace({ @required Route<dynamic> oldRoute, @required Route<
      dynamic> newRoute }) {
    assert(!_debugLocked);
    assert(oldRoute != null);
    assert(newRoute != null);
    if (oldRoute == newRoute)
      return;
    assert(() {
      _debugLocked = true;
      return true;
    });
    assert(oldRoute._navigatorState == this);
    assert(newRoute._navigatorState == null);
    assert(oldRoute.overlayEntries.isNotEmpty);
    assert(newRoute.overlayEntries.isEmpty);
    assert(!overlay.debugIsVisible(oldRoute.overlayEntries.last));
    setState(() {
      final int index = _history.indexOf(oldRoute);
      assert(index >= 0);
      newRoute._navigatorState = this;
      newRoute.install(oldRoute.overlayEntries.last);
      _history[index] = newRoute;
      newRoute.didReplace(oldRoute);
      if (index + 1 < _history.length) {
        newRoute.didChangeNext(_history[index + 1]);
        _history[index + 1].didChangePrevious(newRoute);
      } else {
        newRoute.didChangeNext(null);
      }
      if (index > 0)
        _history[index - 1].didChangeNext(newRoute);
      oldRoute.dispose();
    });
    assert(() {
      _debugLocked = false;
      return true;
    });
  }

  /// Push the [newRoute] and dispose the old current Route.
  ///
  /// The new route and the route below the new route (if any) are notified
  /// (see [Route.didPush] and [Route.didChangeNext]). The navigator observer
  /// is not notified about the old route. The old route is disposed (see
  /// [Route.dispose]). The new route is not notified when the old route
  /// is removed (which happens when the new route's animation completes).
  ///
  /// If a [result] is provided, it will be the return value of the old route,
  /// as if the old route had been popped.
  Future<dynamic> pushReplacement(Route<dynamic> newRoute, { dynamic result }) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    final Route<dynamic> oldRoute = _history.last;
    assert(oldRoute != null && oldRoute._navigatorState == this);
    assert(oldRoute.overlayEntries.isNotEmpty);
    assert(newRoute._navigatorState == null);
    assert(newRoute.overlayEntries.isEmpty);
    setState(() {
      final int index = _history.length - 1;
      assert(index >= 0);
      assert(_history.indexOf(oldRoute) == index);
      newRoute._navigatorState = this;
      newRoute.install(_currentOverlayEntry);
      _history[index] = newRoute;
      newRoute.didPush().whenCompleteOrCancel(() {
        // The old route's exit is not animated. We're assuming that the
        // new route completely obscures the old one.
        if (mounted) {
          oldRoute
            ..didComplete(result ?? oldRoute.currentResult)
            ..dispose();
        }
      });
      newRoute.didChangeNext(null);
      if (index > 0)
        _history[index - 1].didChangeNext(newRoute);
      for (NavigatorObserver observer in widget.observers)
        observer.didPush(newRoute, oldRoute);
    });
    assert(() {
      _debugLocked = false;
      return true;
    });
    _cancelActivePointers();
    return newRoute.popped;
  }

  /// Replaces a route that is not currently visible with a new route.
  ///
  /// The route to be removed is the one below the given `anchorRoute`. That
  /// route must not be the first route in the history.
  ///
  /// In every other way, this acts the same as [replace].
  void replaceRouteBelow(
      { @required Route<dynamic> anchorRoute, Route<dynamic> newRoute }) {
    assert(anchorRoute != null);
    assert(anchorRoute._navigatorState == this);
    assert(_history.indexOf(anchorRoute) > 0);
    replace(oldRoute: _history[_history.indexOf(anchorRoute) - 1],
        newRoute: newRoute);
  }

  /// Removes the route below the given `anchorRoute`. The route to be removed
  /// must not currently be visible. The `anchorRoute` must not be the first
  /// route in the history.
  ///
  /// The removed route is disposed (see [Route.dispose]). The route prior to
  /// the removed route, if any, is notified (see [Route.didChangeNext]). The
  /// route above the removed route, if any, is also notified (see
  /// [Route.didChangePrevious]). The navigator observer is not notified.
  void removeRouteBelow(Route<dynamic> anchorRoute) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    assert(anchorRoute._navigatorState == this);
    final int index = _history.indexOf(anchorRoute) - 1;
    assert(index >= 0);
    final Route<dynamic> targetRoute = _history[index];
    assert(targetRoute._navigatorState == this);
    assert(targetRoute.overlayEntries.isEmpty ||
        !overlay.debugIsVisible(targetRoute.overlayEntries.last));
    setState(() {
      _history.removeAt(index);
      final Route<dynamic> nextRoute = index < _history.length ? _history[index] : null;
      final Route<dynamic> previousRoute = index > 0 ? _history[index - 1] : null;
      if (previousRoute != null)
        previousRoute.didChangeNext(nextRoute);
      if (nextRoute != null)
        nextRoute.didChangePrevious(previousRoute);
      targetRoute.dispose();
    });
    assert(() {
      _debugLocked = false;
      return true;
    });
  }

  /// Push the given route and then remove all the previous routes until the
  /// `predicate` returns true.
  ///
  /// The predicate may be applied to the same route more than once if
  /// [Route.willHandlePopInternally] is true.
  ///
  /// To remove routes until a route with a certain name, use the
  /// [RoutePredicate] returned from [ModalRoute.withName].
  ///
  /// To remove all the routes before the pushed route, use a [RoutePredicate]
  /// that always returns false.
  Future<dynamic> pushAndRemoveUntil(Route<dynamic> newRoute,
      RoutePredicate predicate) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    final List<Route<dynamic>> removedRoutes = <Route<dynamic>>[];
    while (_history.isNotEmpty && !predicate(_history.last)) {
      final Route<dynamic> removedRoute = _history.removeLast();
      assert(removedRoute != null && removedRoute._navigatorState == this);
      assert(removedRoute.overlayEntries.isNotEmpty);
      removedRoutes.add(removedRoute);
    }
    assert(newRoute._navigatorState == null);
    assert(newRoute.overlayEntries.isEmpty);
    setState(() {
      final Route<dynamic> oldRoute = _history.isNotEmpty ? _history.last : null;
      newRoute._navigatorState = this;
      newRoute.install(_currentOverlayEntry);
      _history.add(newRoute);
      newRoute.didPush().whenCompleteOrCancel(() {
        if (mounted) {
          for (Route<dynamic> route in removedRoutes)
            route.dispose();
        }
      });
      newRoute.didChangeNext(null);
      if (oldRoute != null)
        oldRoute.didChangeNext(newRoute);
      for (NavigatorObserver observer in widget.observers)
        observer.didPush(newRoute, oldRoute);
    });
    assert(() {
      _debugLocked = false;
      return true;
    });
    _cancelActivePointers();
    return newRoute.popped;
  }

  /// Tries to pop the current route, first giving the active route the chance
  /// to veto the operation using [Route.willPop]. This method is typically
  /// called instead of [pop] when the user uses a back button. For example on
  /// Android it's called by the binding for the system's back button.
  ///
  /// See also:
  ///
  /// * [Form], which provides a [Form.onWillPop] callback that enables the form
  ///   to veto a [maybePop] initiated by the app's back button.
  /// * [ModalRoute], which has as a [ModalRoute.willPop] method that can be
  ///   defined by a list of [WillPopCallback]s.
  Future<bool> maybePop([dynamic result]) async {
    final Route<dynamic> route = _history.last;
    assert(route._navigatorState == this);
    final RoutePopDisposition disposition = await route.willPop();
    if (disposition != RoutePopDisposition.bubble && mounted) {
      if (disposition == RoutePopDisposition.pop)
        pop(result);
      return true;
    }
    return false;
  }

  /// Removes the top route in the [BasicNavigator]'s history.
  ///
  /// If an argument is provided, that argument will be the return value of the
  /// route (see [Route.didPop]).
  ///
  /// If there are any routes left on the history, the top remaining route is
  /// notified (see [Route.didPopNext]), and the method returns true. In that
  /// case, if the [BasicNavigator] has any [BasicNavigator.observers], they will be notified
  /// as well (see [NavigatorObserver.didPop]). Otherwise, if the popped route
  /// was the last route, the method returns false.
  ///
  /// Ongoing gestures within the current route are canceled when a route is
  /// popped.
  bool pop([dynamic result]) {
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    final Route<dynamic> route = _history.last;
    assert(route._navigatorState == this);
    bool debugPredictedWouldPop;
    assert(() {
      debugPredictedWouldPop = !route.willHandlePopInternally;
      return true;
    });
    if (route.didPop(result ?? route.currentResult)) {
      assert(debugPredictedWouldPop);
      if (_history.length > 1) {
        setState(() {
          // We use setState to guarantee that we'll rebuild, since the routes
          // can't do that for themselves, even if they have changed their own
          // state (e.g. ModalScope.isCurrent).
          _history.removeLast();
          // If route._navigator is null, the route called finalizeRoute from
          // didPop, which means the route has already been disposed and doesn't
          // need to be added to _poppedRoutes for later disposal.
          if (route._navigatorState != null)
            _poppedRoutes.add(route);
          _history.last.didPopNext(route);
          for (NavigatorObserver observer in widget.observers)
            observer.didPop(route, _history.last);
        });
      } else {
        assert(() {
          _debugLocked = false;
          return true;
        });
        return false;
      }
    } else {
      assert(!debugPredictedWouldPop);
    }
    assert(() {
      _debugLocked = false;
      return true;
    });
    _cancelActivePointers();
    return true;
  }

  /// Immediately remove `route` and [Route.dispose] it.
  ///
  /// The route's animation does not run and the future returned from pushing
  /// the route will not complete. Ongoing input gestures are cancelled. If
  /// the [BasicNavigator] has any [BasicNavigator.observers], they will be notified with
  /// [NavigatorObserver.didRemove].
  ///
  /// This method is used to dismiss dropdown menus that are up when the screen's
  /// orientation changes.
  void removeRoute(Route<dynamic> route) {
    assert(route != null);
    assert(!_debugLocked);
    assert(() {
      _debugLocked = true;
      return true;
    });
    assert(route._navigatorState == this);
    final int index = _history.indexOf(route);
    assert(index != -1);
    final Route<dynamic> previousRoute = index > 0 ? _history[index - 1] : null;
    final Route<dynamic> nextRoute = (index + 1 < _history.length) ? _history[index + 1] : null;
    setState(() {
      _history.removeAt(index);
      previousRoute?.didChangeNext(nextRoute);
      nextRoute?.didChangePrevious(previousRoute);
      for (NavigatorObserver observer in widget.observers)
        observer.didRemove(route, previousRoute);
      route.dispose();
    });
    assert(() {
      _debugLocked = false;
      return true;
    });
    _cancelActivePointers();
  }

  /// Complete the lifecycle for a route that has been popped off the navigator.
  ///
  /// When the navigator pops a route, the navigator retains a reference to the
  /// route in order to call [Route.dispose] if the navigator itself is removed
  /// from the tree. When the route is finished with any exit animation, the
  /// route should call this function to complete its lifecycle (e.g., to
  /// receive a call to [Route.dispose]).
  ///
  /// The given `route` must have already received a call to [Route.didPop].
  /// This function may be called directly from [Route.didPop] if [Route.didPop]
  /// will return true.
  void finalizeRoute(Route<dynamic> route) {
    _poppedRoutes.remove(route);
    route.dispose();
  }

  /// Repeatedly calls [pop] until the given `predicate` returns true.
  ///
  /// The predicate may be applied to the same route more than once if
  /// [Route.willHandlePopInternally] is true.
  ///
  /// To pop until a route with a certain name, use the [RoutePredicate]
  /// returned from [ModalRoute.withName].
  void popUntil(RoutePredicate predicate) {
    while (!predicate(_history.last))
      pop();
  }

  /// Whether this navigator can be popped.
  ///
  /// The only route that cannot be popped off the navigator is the initial
  /// route.
  bool canPop() {
    assert(_history.isNotEmpty);
    return _history.length > 1 || _history[0].willHandlePopInternally;
  }

  /// Starts a gesture that results in popping the navigator.
  NavigationGestureController startPopGesture() {
    if (canPop())
      return _history.last.startPopGesture();
    return null;
  }

  /// Whether a gesture controlled by a [NavigationGestureController] is currently in progress.
  bool get userGestureInProgress => _userGestureInProgress;

  // TODO(mpcomplete): remove this bool when we fix
  // https://github.com/flutter/flutter/issues/5577
  bool _userGestureInProgress = false;

  /// The navigator is being controlled by a user gesture.
  ///
  /// Used for the iOS back gesture.
  void didStartUserGesture() {
    _userGestureInProgress = true;
    for (NavigatorObserver observer in widget.observers)
      observer.didStartUserGesture();
  }

  /// A user gesture is no longer controlling the navigator.
  void didStopUserGesture() {
    _userGestureInProgress = false;
    for (NavigatorObserver observer in widget.observers)
      observer.didStopUserGesture();
  }

  final Set<int> _activePointers = new Set<int>();

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _cancelActivePointers() {
    // TODO(abarth): This mechanism is far from perfect. See https://github.com/flutter/flutter/issues/4770
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      // If we're between frames (SchedulerPhase.idle) then absorb any
      // subsequent pointers from this frame. The absorbing flag will be
      // reset in the next frame, see build().
      final RenderAbsorbPointer absorber = _overlayKey.currentContext
          ?.ancestorRenderObjectOfType(
          const TypeMatcher<RenderAbsorbPointer>());
      setState(() {
        absorber?.absorbing = true;
      });
    }
    for (int pointer in _activePointers.toList())
      WidgetsBinding.instance.cancelPointer(pointer);
  }

  @override
  Widget build(BuildContext context) {
    assert(!_debugLocked);
    assert(_history.isNotEmpty);
    return new Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      child: new AbsorbPointer(
        absorbing: false,
        // it's mutated directly by _cancelActivePointers above
        child: new FocusScope(
          node: focusScopeNode,
          autofocus: true,
          child: new Overlay(
            key: _overlayKey,
            initialEntries: _initialOverlayEntries,
          ),
        ),
      ),
    );
  }

  // Abstract methods:

  /// Push a named route onto the navigator.
  ///
  /// The route name will be passed to [Navigator.onGenerateRoute]. The returned
  /// route will be pushed into the navigator.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// Navigator.of(context).pushNamed('/nyc/1776');
  /// ```
  Future<dynamic> pushNamed(String name, {dynamic arguments});

  /// Push the route with the given name and then remove all the previous routes
  /// until the `predicate` returns true.
  ///
  /// The predicate may be applied to the same route more than once if
  /// [Route.willHandlePopInternally] is true.
  ///
  /// To remove routes until a route with a certain name, use the
  /// [RoutePredicate] returned from [ModalRoute.withName].
  ///
  /// To remove all the routes before the pushed route, use a [RoutePredicate]
  /// that always returns false.
  Future<dynamic> pushNamedAndRemoveUntil(String routeName, RoutePredicate predicate, {dynamic arguments});

  /// Push the route named [name] and dispose the old current route.
  ///
  /// The route name will be passed to [Navigator.onGenerateRoute]. The returned
  /// route will be pushed into the navigator.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  Future<dynamic> pushReplacementNamed(String name, { dynamic result , dynamic arguments});
}

/// The state for a [Navigator] widget.
class _NavigatorState extends NavigatorState<Navigator> {
  @override
  void _createInitialRoutes() {
    String initialRouteName = widget.initialRoute ?? Navigator.defaultRouteName;
    if (initialRouteName.startsWith('/') && initialRouteName.length > 1) {
      initialRouteName = initialRouteName.substring(1); // strip leading '/'
      assert(Navigator.defaultRouteName == '/');
      final List<String> plannedInitialRouteNames = <String>[
        Navigator.defaultRouteName,
      ];
      final List<Route<dynamic>> plannedInitialRoutes = <Route<dynamic>>[
        _createNamedRoute(Navigator.defaultRouteName, allowNull: true),
      ];
      final List<String> routeParts = initialRouteName.split('/');
      if (initialRouteName.isNotEmpty) {
        String routeName = '';
        for (String part in routeParts) {
          routeName += '/$part';
          plannedInitialRouteNames.add(routeName);
          plannedInitialRoutes.add(_createNamedRoute(routeName, allowNull: true));
        }
      }
      if (plannedInitialRoutes.contains(null)) {
        assert(() {
          FlutterError.reportError(
            new FlutterErrorDetails( // ignore: prefer_const_constructors, https://github.com/dart-lang/sdk/issues/29952
                exception:
                'Could not navigate to initial route.\n'
                    'The requested route name was: "/$initialRouteName"\n'
                    'The following routes were therefore attempted:\n'
                    ' * ${plannedInitialRouteNames.join("\n * ")}\n'
                    'This resulted in the following objects:\n'
                    ' * ${plannedInitialRoutes.join("\n * ")}\n'
                    'One or more of those objects was null, and therefore the initial route specified will be '
                    'ignored and "${Navigator.defaultRouteName}" will be used instead.'
            ),
          );
          return true;
        });
        push(_createNamedRoute(Navigator.defaultRouteName));
      } else {
        for (Route<dynamic> route in plannedInitialRoutes)
          push(route);
      }
    } else {
      Route<dynamic> route;
      if (initialRouteName != Navigator.defaultRouteName)
        route = _createNamedRoute(initialRouteName, allowNull: true);
      if (route == null)
        route = _createNamedRoute(Navigator.defaultRouteName);
      push(route);
    }
  }

  Route<dynamic> _createNamedRoute(String name, { bool allowNull: false, dynamic arguments}) {
    assert(!_debugLocked);
    assert(name != null);
    final RouteSettings settings = new RouteSettings(
      name: name,
      arguments: arguments,
      isInitialRoute: _history.isEmpty,
    );
    Route<dynamic> route = widget.onGenerateRoute(settings);
    if (route == null && !allowNull) {
      assert(() {
        if (widget.onUnknownRoute == null) {
          throw new FlutterError(
              'If a Navigator has no onUnknownRoute, then its onGenerateRoute must never return null.\n'
                  'When trying to build the route "$name", onGenerateRoute returned null, but there was no '
                  'onUnknownRoute callback specified.\n'
                  'The Navigator was:\n'
                  '  $this'
          );
        }
        return true;
      });
      route = widget.onUnknownRoute(settings);
      assert(() {
        if (route == null) {
          throw new FlutterError(
              'A Navigator\'s onUnknownRoute returned null.\n'
                  'When trying to build the route "$name", both onGenerateRoute and onUnknownRoute returned '
                  'null. The onUnknownRoute callback should never return null.\n'
                  'The Navigator was:\n'
                  '  $this'
          );
        }
        return true;
      });
    }
    return route;
  }

  /// Push a named route onto the navigator.
  ///
  /// The route name will be passed to [Navigator.onGenerateRoute]. The returned
  /// route will be pushed into the navigator.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// Navigator.of(context).pushNamed('/nyc/1776');
  /// ```
  @override
  Future<dynamic> pushNamed(String name, {dynamic arguments}) {
    return push(_createNamedRoute(name, arguments: arguments));
  }


  /// Push the route with the given name and then remove all the previous routes
  /// until the `predicate` returns true.
  ///
  /// The predicate may be applied to the same route more than once if
  /// [Route.willHandlePopInternally] is true.
  ///
  /// To remove routes until a route with a certain name, use the
  /// [RoutePredicate] returned from [ModalRoute.withName].
  ///
  /// To remove all the routes before the pushed route, use a [RoutePredicate]
  /// that always returns false.
  @override
  Future<dynamic> pushNamedAndRemoveUntil(String routeName, RoutePredicate predicate, {dynamic arguments}) {
    return pushAndRemoveUntil(_createNamedRoute(routeName, arguments: arguments), predicate);
  }

  /// Push the route named [name] and dispose the old current route.
  ///
  /// The route name will be passed to [Navigator.onGenerateRoute]. The returned
  /// route will be pushed into the navigator.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  @override
  Future<dynamic> pushReplacementNamed(String name, { dynamic result, dynamic arguments }) {
    return pushReplacement(_createNamedRoute(name, arguments: arguments), result: result);
  }
}

class BasicNavigator extends StatefulWidget {
  /// Creates a widget that maintains a stack-based history of child widgets.
  ///
  /// The [onGenerateRoute] argument must not be null.
  const BasicNavigator({
    Key key,
    @required this.onGenerateRoute,
    this.onUnknownRoute,
    this.observers: const <NavigatorObserver>[]
  }) : assert(onGenerateRoute != null),
        super(key: key);

  /// Called to generate a route for a given [RouteSettings].
  final RouteFactory onGenerateRoute;

  /// Called when [onGenerateRoute] fails to generate a route.
  ///
  /// This callback is typically used for error handling. For example, this
  /// callback might always generate a "not found" page that describes the route
  /// that wasn't found.
  ///
  /// Unknown routes can arise either from errors in the app or from external
  /// requests to push routes, such as from Android intents.
  final RouteFactory onUnknownRoute;

  /// A list of observers for this navigator.
  final List<NavigatorObserver> observers;

  /// Adds the given route to the history of the navigator that most tightly
  /// encloses the given context, and transitions to it.
  ///
  /// The new route and the previous route (if any) are notified (see
  /// [Route.didPush] and [Route.didChangeNext]). If the [BasicNavigator] has any
  /// [BasicNavigator.observers], they will be notified as well (see
  /// [NavigatorObserver.didPush]).
  ///
  /// Ongoing gestures within the current route are canceled when a new route is
  /// pushed.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  static Future<dynamic> push(BuildContext context, Route<dynamic> route) {
    return BasicNavigator.of(context).push(route);
  }

  /// Returns the value of the current route's [Route.willPop] method. This
  /// method is typically called before a user-initiated [pop]. For example on
  /// Android it's called by the binding for the system's back button.
  ///
  /// See also:
  ///
  /// * [Form], which provides an `onWillPop` callback that enables the form
  ///   to veto a [pop] initiated by the app's back button.
  /// * [ModalRoute], which provides a `scopedWillPopCallback` that can be used
  ///   to define the route's `willPop` method.
  static Future<bool> maybePop(BuildContext context, [ dynamic result ]) {
    return BasicNavigator.of(context).maybePop(result);
  }

  /// Pop a route off the navigator that most tightly encloses the given context.
  ///
  /// Tries to removes the current route, calling its didPop() method. If that
  /// method returns false, then nothing else happens. Otherwise, the observer
  /// (if any) is notified using its didPop() method, and the previous route is
  /// notified using [Route.didChangeNext].
  ///
  /// If non-null, `result` will be used as the result of the route. Routes
  /// such as dialogs or popup menus typically use this mechanism to return the
  /// value selected by the user to the widget that created their route. The
  /// type of `result`, if provided, must match the type argument of the class
  /// of the current route. (In practice, this is usually "dynamic".)
  ///
  /// Returns true if a route was popped; returns false if there are no further
  /// previous routes.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// BasicNavigator.pop(context);
  /// ```
  static bool pop(BuildContext context, [ dynamic result ]) {
    return BasicNavigator.of(context).pop(result);
  }

  /// Calls [pop] repeatedly until the predicate returns true.
  ///
  /// The predicate may be applied to the same route more than once if
  /// [Route.willHandlePopInternally] is true.
  ///
  /// To pop until a route with a certain name, use the [RoutePredicate]
  /// returned from [ModalRoute.withName].
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// BasicNavigator.popUntil(context, ModalRoute.withName('/login'));
  /// ```
  static void popUntil(BuildContext context, RoutePredicate predicate) {
    BasicNavigator.of(context).popUntil(predicate);
  }

  /// Whether the navigator that most tightly encloses the given context can be
  /// popped.
  ///
  /// The initial route cannot be popped off the navigator, which implies that
  /// this function returns true only if popping the navigator would not remove
  /// the initial route.
  static bool canPop(BuildContext context) {
    final _BasicNavigatorState navigatorState = context.ancestorStateOfType(const TypeMatcher<_BasicNavigatorState>());
    return navigatorState != null && navigatorState.canPop();
  }

  /// Replace the current route by pushing [route] and then disposing the
  /// current route.
  ///
  /// The new route and the route below the new route (if any) are notified
  /// (see [Route.didPush] and [Route.didChangeNext]). The navigator observer
  /// is not notified about the old route. The old route is disposed (see
  /// [Route.dispose]).
  ///
  /// If a [result] is provided, it will be the return value of the old route,
  /// as if the old route had been popped.
  ///
  /// Returns a [Future] that completes to the `result` value passed to [pop]
  /// when the pushed route is popped off the navigator.
  static Future<dynamic> pushReplacement(BuildContext context, Route<dynamic> route, { dynamic result }) {
    return BasicNavigator.of(context).pushReplacement(route, result: result);
  }

  /// Immediately remove `route` and [Route.dispose] it.
  ///
  /// The route's animation does not run and the future returned from pushing
  /// the route will not complete. Ongoing input gestures are cancelled. If
  /// the [BasicNavigator] has any [BasicNavigator.observers], they will be notified with
  /// [NavigatorObserver.didRemove].
  ///
  /// The routes before and after the removed route, if any, are notified with
  /// [Route.didChangeNext] and [Route.didChangePrevious].
  ///
  /// This method is used to dismiss dropdown menus that are up when the screen's
  /// orientation changes.
  static void removeRoute(BuildContext context, Route<dynamic> route) {
    return BasicNavigator.of(context).removeRoute(route);
  }

  /// The state from the closest instance of this class that encloses the given context.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// BasicNavigator.of(context)
  ///   ..pop()
  ///   ..pop()
  ///   ..pushNamed('/settings');
  /// ```
  static _BasicNavigatorState of(BuildContext context) {
    final _BasicNavigatorState navigatorState = context.ancestorStateOfType(const TypeMatcher<_BasicNavigatorState>());
    assert(() {
      if (navigatorState == null) {
        throw new FlutterError(
            'BasicNavigator operation requested with a context that does not include a BasicNavigator.\n'
                'The context used to push or pop routes from the BasicNavigator must be that of a widget that is a descendant of a BasicNavigator widget.'
        );
      }
      return true;
    });
    return navigatorState;
  }

  @override
  NavigatorState<BasicNavigator> createState() => new _BasicNavigatorState();
}

/// The state for a [BasicNavigator] widget.
class _BasicNavigatorState extends NavigatorState<BasicNavigator> {
  /// Stub to support NavigatorState interface.
  ///
  /// Use [Navigator] if you wish to use this functionality.  It is not
  /// supported by [BasicNavigator].
  @deprecated
  @override
  Future<dynamic> pushNamed(String name, {dynamic arguments}) {
    assert(() {
      throw new FlutterError(
          'BasicNavigator does not support "pushNamed".  Use Navigator instead.');
    });
    return null;
  }


  /// Stub to support NavigatorState interface.
  ///
  /// Use [Navigator] if you wish to use this functionality.  It is not
  /// supported by [BasicNavigator].
  @deprecated
  @override
  Future<dynamic> pushNamedAndRemoveUntil(String routeName, RoutePredicate predicate, {dynamic arguments}) {
    assert(() {
      throw new FlutterError(
          'BasicNavigator does not support "pushNamedAndRemoveUntil".  Use Navigator instead.');
    });
    return null;
  }

  /// Stub to support NavigatorState interface.
  ///
  /// Use [Navigator] if you wish to use this functionality.  It is not
  /// supported by [BasicNavigator].
  @deprecated
  @override
  Future<dynamic> pushReplacementNamed(String name, { dynamic result, dynamic arguments }) {
    assert(() {
      throw new FlutterError(
          'BasicNavigator does not support "pushReplacementNamed".  Use Navigator instead.');
    });
    return null;
  }
}
