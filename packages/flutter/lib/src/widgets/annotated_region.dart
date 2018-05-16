import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/src/widgets/framework.dart';

/// Annotates a region of the layer tree with a value.
class AnnotatedRegion<T> extends SingleChildRenderObjectWidget {
  /// Creates a new annotated region.
  const AnnotatedRegion({
    Key key,
    @required Widget child,
    @required this.value,
  }) : assert(value != null),
       super(key: key, child: child);

  /// The value inserted into the layer tree.
  final T value;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return new _AnnotatedRegionRenderObject<T>()
      ..value = value;
  }

  @override
  void updateRenderObject(BuildContext context, _AnnotatedRegionRenderObject<T> renderObject) {
    renderObject.value = value;
  }
}

// Render object for the [AnnotatedRegion].
class _AnnotatedRegionRenderObject<T> extends RenderProxyBox {
  T _value;
  /// The value to be inserted into the layer tree.
  T get value => _value;
  set value(T newValue) {
    if (_value == newValue)
      return;
    _value = value;
  }

  @override
  final bool alwaysNeedsCompositing = true;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.pushLayer(
        new AnnotatedRegionLayer<T>(value),
        super.paint,
        offset,
      );
    }
  }
}
