import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget which provides a semantic name route name.
///
/// On iOS, no additional semantic information is inserted.
///
/// See also:
///
///  * [SemanticsProperties.routeName], for a description of how route name
///    semantics work.
class RouteName extends StatelessWidget  {

  /// Creates a widget which provides a semantic route name.
  ///
  /// [child] and [routeName] are required arguments.
  const RouteName({
    Key key,
    this.child,
    @required this.routeName,
  }) : super(key: key);

  /// A semantic name for the route.
  /// 
  /// On iOS platforms this value is ignored.
  final String routeName;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return child;
    }
    return new Semantics(
      routeName: true,
      explicitChildNodes: true,
      value: routeName,
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(new StringProperty('routeName', routeName, defaultValue: null));
  }
}
