import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/gestures.dart' show kMinFlingVelocity;

/// This widget allows 2D transform interactions on its child in relation to its
/// parent. The user can transform the child by dragging to pan or pinching to
/// zoom and rotate. All event callbacks for GestureDetector are supported, and
/// the coordinates that are given are untransformed and in relation to the
/// original position of the child.
@immutable
class GestureTransformable extends StatelessWidget {
  const GestureTransformable({
    Key key,
    @required this.child,
    this.maxScale = 2.5,
    this.minScale = 0.8,
    this.boundaryRect = const Rect.fromLTRB(
      -double.infinity, -double.infinity, double.infinity, double.infinity,
    ),
    this.initialTranslation,
    this.initialScale,
    this.initialRotation,
    this.disableTranslation = false,
    this.disableScale = false,
    this.disableRotation = false,
    this.reset = false,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressUp,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onResetEnd,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
  }) : assert(child != null),
       assert(minScale != null),
       assert(minScale > 0),
       assert(disableTranslation != null),
       assert(disableScale != null),
       assert(disableRotation != null),
       assert(reset != null),
       assert(
         !reset || onResetEnd != null,
         'Must implement onResetEnd to use reset.',
       ),
       super(key: key);

  /// A Rect that defines the area that can be viewed by the viewport.
  ///
  /// Panning beyond boundaryRect will be stopped. boundaryRect does not rotate
  /// with the rest of the scene, so it is always aligned with the viewport.
  ///
  /// Defaults to an infinite plane, which results in no limit to the distance
  /// that the viewport can be transformed.
  final Rect boundaryRect;

  /// The child to perform the transformations on.
  ///
  /// Cannot be null.
  final Widget child;

  /// If true, the user will be prevented from translating.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///   * [disableScale]
  ///   * [disableRotation]
  final bool disableTranslation;

  /// If true, the user will be prevented from scaling.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///   * [disableTranslation]
  ///   * [disableRotation]
  final bool disableScale;

  /// If true, the user will be prevented from rotating.
  ///
  /// Defaults to false.
  ///
  /// See also:
  ///   * [disableTranslation]
  ///   * [disableScale]
  final bool disableRotation;

  /// Sets the initial translation value of the transform.
  ///
  /// Defaults to Offset.zero.
  final Offset initialTranslation;

  /// Sets the initial scale value of the transform.
  ///
  /// Defaults to 1.0.
  final double initialScale;

  /// Sets the initial rotation value of the transform.
  ///
  /// Defaults to 0.0.
  final double initialRotation;

  /// The maximum allowed scale.
  ///
  /// The scale will be clamped between this and [minScale].
  ///
  /// A maxScale of null, the default, has no bounds.
  final double maxScale;

  /// The minimum allowed scale.
  ///
  /// The scale will be clamped between this and [maxScale].
  ///
  /// A minScale of null, the default, has no bounds.
  final double minScale;

  /// A pre-transformation proxy for [GestureDetector.onDoubleTap].
  final GestureTapCallback onDoubleTap;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragCancel].
  final GestureDragCancelCallback onHorizontalDragCancel;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragDown].
  final GestureDragDownCallback onHorizontalDragDown;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragEnd].
  final GestureDragEndCallback onHorizontalDragEnd;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragStart].
  final GestureDragStartCallback onHorizontalDragStart;

  /// A pre-transformation proxy for [GestureDetector.onHorizontalDragUpdate].
  final GestureDragUpdateCallback onHorizontalDragUpdate;

  /// A pre-transformation proxy for [GestureDetector.onLongPress].
  final GestureLongPressCallback onLongPress;

  /// A pre-transformation proxy for [GestureDetector.onLongPressUp].
  final GestureLongPressUpCallback onLongPressUp;

  /// A pre-transformation proxy for [GestureDetector.onPanCancel].
  final GestureDragCancelCallback onPanCancel;

  /// A pre-transformation proxy for [GestureDetector.onPanDown].
  final GestureDragDownCallback onPanDown;

  /// A pre-transformation proxy for [GestureDetector.onPanEnd].
  final GestureDragEndCallback onPanEnd;

  /// A pre-transformation proxy for [GestureDetector.onPanStart].
  final GestureDragStartCallback onPanStart;

  /// A pre-transformation proxy for [GestureDetector.onPanUpdate].
  final GestureDragUpdateCallback onPanUpdate;

  /// Called when the transform finishes resetting to its initial value.
  ///
  /// Resetting happens when [reset] is set to true. This callback should set
  /// [reset] to false.
  final VoidCallback onResetEnd;

  /// A pre-transformation proxy for [GestureDetector.onScaleEnd].
  final GestureScaleEndCallback onScaleEnd;

  /// A pre-transformation proxy for [GestureDetector.onScaleStart].
  final GestureScaleStartCallback onScaleStart;

  /// A pre-transformation proxy for [GestureDetector.onScaleUpdate].
  final GestureScaleUpdateCallback onScaleUpdate;

  /// A pre-transformation proxy for [GestureDetector.onTap].
  final GestureTapCallback onTap;

  /// A pre-transformation proxy for [GestureDetector.onTapCancel].
  final GestureTapCancelCallback onTapCancel;

  /// A pre-transformation proxy for [GestureDetector.onTapDown].
  final GestureTapDownCallback onTapDown;

  /// A pre-transformation proxy for [GestureDetector.onTapUp].
  final GestureTapUpCallback onTapUp;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragCancel].
  final GestureDragCancelCallback onVerticalDragCancel;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragDown].
  final GestureDragDownCallback onVerticalDragDown;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragEnd].
  final GestureDragEndCallback onVerticalDragEnd;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragStart].
  final GestureDragStartCallback onVerticalDragStart;

  /// A pre-transformation proxy for [GestureDetector.onVerticalDragStart].
  final GestureDragUpdateCallback onVerticalDragUpdate;

  /// Whether to reset the child to its original transformation state.
  ///
  /// If set to true, this widget will animate back to its initial transform
  /// and call [onResetEnd] when done. When utilizing reset, [onResetEnd] should
  /// also be implemented, and it should set reset to false when called.
  ///
  /// Defaults to false.
  final bool reset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return _GestureTransformableSized(
          child: child,
          maxScale: maxScale,
          minScale: minScale,
          boundaryRect: boundaryRect,
          initialTranslation: initialTranslation,
          initialScale: initialScale,
          initialRotation: initialRotation,
          disableTranslation: disableTranslation,
          disableScale: disableScale,
          disableRotation: disableRotation,
          reset: reset,
          onTapDown: onTapDown,
          onTapUp: onTapUp,
          onTap: onTap,
          onTapCancel: onTapCancel,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          onLongPressUp: onLongPressUp,
          onVerticalDragDown: onVerticalDragDown,
          onVerticalDragStart: onVerticalDragStart,
          onVerticalDragUpdate: onVerticalDragUpdate,
          onVerticalDragEnd: onVerticalDragEnd,
          onVerticalDragCancel: onVerticalDragCancel,
          onHorizontalDragDown: onHorizontalDragDown,
          onHorizontalDragStart: onHorizontalDragStart,
          onHorizontalDragUpdate: onHorizontalDragUpdate,
          onHorizontalDragEnd: onHorizontalDragEnd,
          onHorizontalDragCancel: onHorizontalDragCancel,
          onPanDown: onPanDown,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          onPanCancel: onPanCancel,
          onResetEnd: onResetEnd,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          onScaleEnd: onScaleEnd,
          size: Size(constraints.maxWidth, constraints.maxHeight),
        );
      },
    );
  }
}

@immutable
class _GestureTransformableSized extends StatefulWidget {
  const _GestureTransformableSized({
    @required this.child,
    @required this.size,
    this.maxScale,
    this.minScale,
    this.boundaryRect,
    this.initialTranslation,
    this.initialScale,
    this.initialRotation,
    this.disableTranslation,
    this.disableScale,
    this.disableRotation,
    this.reset,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressUp,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onResetEnd,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
  }) : assert(child != null),
       assert(minScale != null),
       assert(minScale > 0),
       assert(disableTranslation != null),
       assert(disableScale != null),
       assert(disableRotation != null),
       assert(reset != null),
       assert(
         !reset || onResetEnd != null,
         'Must implement onResetEnd to use reset.',
       );

  final Widget child;
  final Size size;
  final bool reset;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final GestureTapCallback onTap;
  final GestureTapCancelCallback onTapCancel;
  final GestureTapCallback onDoubleTap;
  final GestureLongPressCallback onLongPress;
  final GestureLongPressUpCallback onLongPressUp;
  final GestureDragDownCallback onVerticalDragDown;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;
  final GestureDragDownCallback onHorizontalDragDown;
  final GestureDragStartCallback onHorizontalDragStart;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;
  final GestureDragCancelCallback onHorizontalDragCancel;
  final GestureDragDownCallback onPanDown;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;
  final VoidCallback onResetEnd;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;
  final double maxScale;
  final double minScale;
  final Rect boundaryRect;
  final bool disableTranslation;
  final bool disableScale;
  final bool disableRotation;
  final Offset initialTranslation;
  final double initialScale;
  final double initialRotation;

  @override _GestureTransformableState createState() => _GestureTransformableState();
}

// A single user event can only represent one of these gestures. The user can't
// do multiple at the same time, which results in more precise transformations.
enum _GestureType {
  translate,
  scale,
  rotate,
}

// This is public only for access from a unit test.
class _GestureTransformableState extends State<_GestureTransformableSized> with TickerProviderStateMixin {
  Animation<Offset> _animation;
  AnimationController _controller;
  Animation<Matrix4> _animationReset;
  AnimationController _controllerReset;
  // The translation that will be applied to the scene (not viewport).
  // A positive x offset moves the scene right, viewport left.
  // A positive y offset moves the scene down, viewport up.
  Offset _translateFromScene; // Point where a single translation began.
  double _scaleStart; // Scale value at start of scaling gesture.
  double _rotationStart = 0.0; // Rotation at start of rotation gesture.
  Matrix4 _transform = Matrix4.identity();
  double _currentRotation = 0.0;
  _GestureType gestureType;

  // This value was eyeballed as something that feels right for a photo viewer.
  static const double _kDrag = 0.0000135;

  // Given a velocity and drag, calculate the time at which motion will come to
  // a stop, within the margin of effectivelyMotionless.
  static double _getFinalTime(double velocity, double drag) {
    const double effectivelyMotionless = 10.0;
    return math.log(effectivelyMotionless / velocity) / math.log(drag / 100);
  }

  // The transformation matrix that gives the initial home position.
  Matrix4 get _initialTransform {
    Matrix4 matrix = Matrix4.identity();
    if (widget.initialTranslation != null) {
      matrix = matrixTranslate(matrix, widget.initialTranslation);
    }
    if (widget.initialScale != null) {
      matrix = matrixScale(matrix, widget.initialScale);
    }
    if (widget.initialRotation != null) {
      matrix = matrixRotate(matrix, widget.initialRotation, Offset.zero);
    }
    return matrix;
  }

  // Return the scene point at the given viewport point.
  static Offset fromViewport(Offset viewportPoint, Matrix4 transform) {
    // On viewportPoint, perform the inverse transformation of the scene to get
    // where the point would be in the scene before the transformation.
    final Matrix4 inverseMatrix = Matrix4.inverted(transform);
    final Vector3 untransformed = inverseMatrix.transform3(Vector3(
      viewportPoint.dx,
      viewportPoint.dy,
      0,
    ));
    return Offset(untransformed.x, untransformed.y);
  }

  // Get the offset of the current widget from the global screen coordinates.
  // TODO(justinmc): Protect against calling this during first build.
  static Offset getOffset(BuildContext context) {
    final RenderBox renderObject = context.findRenderObject();
    return renderObject.localToGlobal(Offset.zero);
  }

  @override
  void initState() {
    super.initState();
    _transform = _initialTransform;
    _controller = AnimationController(
      vsync: this,
    );
    _controllerReset = AnimationController(
      vsync: this,
    );
    if (widget.reset) {
      _animateResetInitialize();
    }
  }

  @override
  void didUpdateWidget(_GestureTransformableSized oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reset && !oldWidget.reset && _animationReset == null) {
      _animateResetInitialize();
    } else if (!widget.reset && oldWidget.reset && _animationReset != null) {
      _animateResetStop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A GestureDetector allows the detection of panning and zooming gestures on
    // its child, which is the CustomPaint.
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Necessary when translating off screen
      onTapDown: widget.onTapDown == null ? null : (TapDownDetails details) {
        widget.onTapDown(TapDownDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onTapUp: widget.onTapUp == null ? null : (TapUpDetails details) {
        widget.onTapUp(TapUpDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onTap: widget.onTap,
      onTapCancel: widget.onTapCancel,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onLongPressUp: widget.onLongPressUp,
      onVerticalDragDown: widget.onVerticalDragDown == null ? null : (DragDownDetails details) {
        widget.onVerticalDragDown(DragDownDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onVerticalDragStart: widget.onVerticalDragStart == null ? null : (DragStartDetails details) {
        widget.onVerticalDragStart(DragStartDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onVerticalDragUpdate: widget.onVerticalDragUpdate == null ? null : (DragUpdateDetails details) {
        widget.onVerticalDragUpdate(DragUpdateDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onVerticalDragEnd: widget.onVerticalDragEnd,
      onVerticalDragCancel: widget.onVerticalDragCancel,
      onHorizontalDragDown: widget.onHorizontalDragDown == null ? null : (DragDownDetails details) {
        widget.onHorizontalDragDown(DragDownDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onHorizontalDragStart: widget.onHorizontalDragStart == null ? null : (DragStartDetails details) {
        widget.onHorizontalDragStart(DragStartDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onHorizontalDragUpdate: widget.onHorizontalDragUpdate == null ? null : (DragUpdateDetails details) {
        widget.onHorizontalDragUpdate(DragUpdateDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onHorizontalDragEnd: widget.onHorizontalDragEnd,
      onHorizontalDragCancel: widget.onHorizontalDragCancel,
      onPanDown: widget.onPanDown == null ? null : (DragDownDetails details) {
        widget.onPanDown(DragDownDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onPanStart: widget.onPanStart == null ? null : (DragStartDetails details) {
        widget.onPanStart(DragStartDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onPanUpdate: widget.onPanUpdate == null ? null : (DragUpdateDetails details) {
        widget.onPanUpdate(DragUpdateDetails(
          globalPosition: fromViewport(details.globalPosition - getOffset(context), _transform),
        ));
      },
      onPanEnd: widget.onPanEnd,
      onPanCancel: widget.onPanCancel,
      onScaleEnd: _onScaleEnd,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: ClipRect(
        child: Transform(
          transform: _transform,
          child: Container(
            width: widget.size.width,
            height: widget.size.height,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  // Return a new matrix representing the given matrix after applying the given
  // translation.
  Matrix4 matrixTranslate(Matrix4 matrix, Offset translation) {
    if (widget.disableTranslation || translation == Offset.zero) {
      return matrix;
    }

    // Clamp translation so the viewport remains inside boundaryRect.
    final double scale = _transform.getMaxScaleOnAxis();
    final Size scaledSize = widget.size / scale;
    final Rect viewportBoundaries = Rect.fromLTRB(
      widget.boundaryRect.left,
      widget.boundaryRect.top,
      widget.boundaryRect.right - scaledSize.width,
      widget.boundaryRect.bottom - scaledSize.height,
    );
    // Translation is reversed (a positive translation moves the scene to the
    // right, viewport to the left).
    final Rect translationBoundaries = Rect.fromLTRB(
      -scale * viewportBoundaries.right,
      -scale * viewportBoundaries.bottom,
      -scale * viewportBoundaries.left,
      -scale * viewportBoundaries.top,
    );
    final Matrix4 nextMatrix = matrix.clone()..translate(
      translation.dx,
      translation.dy,
    );
    final Vector3 nextTranslationVector = nextMatrix.getTranslation();
    final Offset nextTranslation = Offset(
      nextTranslationVector.x,
      nextTranslationVector.y,
    );
    final bool inBoundaries = translationBoundaries.contains(
      Offset(nextTranslation.dx, nextTranslation.dy),
    );
    if (!inBoundaries) {
      // TODO(justinmc): Instead of canceling translation when it goes out of
      // bounds, stop translation at boundary.
      return matrix;
    }

    return nextMatrix;
  }

  // Return a new matrix representing the given matrix after applying the given
  // scale transform.
  Matrix4 matrixScale(Matrix4 matrix, double scale) {
    if (widget.disableScale || scale == 1) {
      return matrix;
    }
    assert(scale != 0);

    // Don't allow a scale that moves the viewport outside of boundaryRect.
    final Offset tl = fromViewport(const Offset(0, 0), _transform);
    final Offset tr = fromViewport(Offset(widget.size.width, 0), _transform);
    final Offset bl = fromViewport(Offset(0, widget.size.height), _transform);
    final Offset br = fromViewport(
      Offset(widget.size.width, widget.size.height),
      _transform,
    );
    if (!widget.boundaryRect.contains(tl)
      || !widget.boundaryRect.contains(tr)
      || !widget.boundaryRect.contains(bl)
      || !widget.boundaryRect.contains(br)) {
      return matrix;
    }

    // Don't allow a scale that results in an overall scale beyond min/max
    // scale.
    final double currentScale = _transform.getMaxScaleOnAxis();
    final double totalScale = currentScale * scale;
    final double clampedTotalScale = totalScale.clamp(
      widget.minScale,
      widget.maxScale,
    );
    final double clampedScale = clampedTotalScale / currentScale;
    return matrix..scale(clampedScale);
  }

  // Return a new matrix representing the given matrix after applying the given
  // rotation transform.
  // Rotating the scene cannot cause the viewport to view beyond boundaryRect.
  Matrix4 matrixRotate(Matrix4 matrix, double rotation, Offset focalPoint) {
    if (widget.disableRotation || rotation == 0) {
      return matrix;
    }
    final Offset focalPointScene = fromViewport(focalPoint, matrix);
    return matrix
      ..translate(focalPointScene.dx, focalPointScene.dy)
      ..rotateZ(-rotation)
      ..translate(-focalPointScene.dx, -focalPointScene.dy);
  }

  // Handle the start of a gesture of _GestureType.
  void _onScaleStart(ScaleStartDetails details) {
    if (widget.onScaleStart != null) {
      widget.onScaleStart(details);
    }

    if (_controller.isAnimating) {
      _controller.stop();
      _controller.reset();
      _animation?.removeListener(_onAnimate);
      _animation = null;
    }
    if (_controllerReset.isAnimating) {
      _animateResetStop();
    }

    gestureType = null;
    setState(() {
      _scaleStart = _transform.getMaxScaleOnAxis();
      _translateFromScene = fromViewport(details.focalPoint, _transform);
      _rotationStart = _currentRotation;
    });
  }

  // Handle an update to an ongoing gesture of _GestureType.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    double scale = _transform.getMaxScaleOnAxis();
    if (widget.onScaleUpdate != null) {
      widget.onScaleUpdate(ScaleUpdateDetails(
        focalPoint: fromViewport(details.focalPoint, _transform),
        scale: details.scale,
        rotation: details.rotation,
      ));
    }
    final Offset focalPointScene = fromViewport(
      details.focalPoint,
      _transform,
    );
    if (gestureType == null) {
      // Decide which type of gesture this is by comparing the amount of scale
      // and rotation in the gesture, if any. Scale starts at 1 and rotation
      // starts at 0. Translate will have 0 scale and 0 rotation because it uses
      // only one finger.
      if ((details.scale - 1).abs() > details.rotation.abs()) {
        gestureType = _GestureType.scale;
      } else if (details.rotation != 0) {
        gestureType = _GestureType.rotate;
      } else {
        gestureType = _GestureType.translate;
      }
    }
    setState(() {
      if (gestureType == _GestureType.scale && _scaleStart != null) {
        // details.scale gives us the amount to change the scale as of the
        // start of this gesture, so calculate the amount to scale as of the
        // previous call to _onScaleUpdate.
        final double desiredScale = _scaleStart * details.scale;
        final double scaleChange = desiredScale / scale;
        _transform = matrixScale(_transform, scaleChange);
        scale = _transform.getMaxScaleOnAxis();

        // While scaling, translate such that the user's two fingers stay on the
        // same places in the scene. That means that the focal point of the
        // scale should be on the same place in the scene before and after the
        // scale.
        final Offset focalPointSceneNext = fromViewport(
          details.focalPoint,
          _transform,
        );
        _transform = matrixTranslate(_transform, focalPointSceneNext - focalPointScene);
      } else if (gestureType == _GestureType.rotate && details.rotation != 0.0) {
        final double desiredRotation = _rotationStart + details.rotation;
        _transform = matrixRotate(_transform, _currentRotation - desiredRotation, details.focalPoint);
        _currentRotation = desiredRotation;
      } else if (_translateFromScene != null && details.scale == 1.0) {
        // Translate so that the same point in the scene is underneath the
        // focal point before and after the movement.
        final Offset translationChange = focalPointScene - _translateFromScene;
        _transform = matrixTranslate(_transform, translationChange);
        _translateFromScene = fromViewport(details.focalPoint, _transform);
      }
    });
  }

  // Handle the end of a gesture of _GestureType.
  void _onScaleEnd(ScaleEndDetails details) {
    if (widget.onScaleEnd != null) {
      widget.onScaleEnd(details);
    }
    setState(() {
      _scaleStart = null;
      _rotationStart = null;
      _translateFromScene = null;
    });

    _animation?.removeListener(_onAnimate);
    _controller.reset();

    // If the scale ended with enough velocity, animate inertial movement.
    if (details.velocity.pixelsPerSecond.distance < kMinFlingVelocity) {
      return;
    }

    final Vector3 translationVector = _transform.getTranslation();
    final Offset translation = Offset(translationVector.x, translationVector.y);
    final FrictionSimulation frictionSimulationX = FrictionSimulation(
      _kDrag,
      translation.dx,
      details.velocity.pixelsPerSecond.dx,
    );
    final FrictionSimulation frictionSimulationY = FrictionSimulation(
      _kDrag,
      translation.dy,
      details.velocity.pixelsPerSecond.dy,
    );
    final double tFinal = _getFinalTime(
      details.velocity.pixelsPerSecond.distance,
      _kDrag,
    );
    _animation = Tween<Offset>(
      begin: translation,
      end: Offset(frictionSimulationX.finalX, frictionSimulationY.finalX),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ));
    _controller.duration = Duration(milliseconds: (tFinal * 1000).round());
    _animation.addListener(_onAnimate);
    _controller.forward();
  }

  // Handle inertia drag animation.
  void _onAnimate() {
    if (!_controller.isAnimating) {
      _animation?.removeListener(_onAnimate);
      _animation = null;
      _controller.reset();
      return;
    }
    setState(() {
      // Translate _transform such that the resulting translation is
      // _animation.value.
      final Vector3 translationVector = _transform.getTranslation();
      final Offset translation = Offset(translationVector.x, translationVector.y);
      final Offset translationScene = fromViewport(translation, _transform);
      final Offset animationScene = fromViewport(_animation.value, _transform);
      final Offset translationChangeScene = animationScene - translationScene;
      _transform = matrixTranslate(_transform, translationChangeScene);
    });
  }

  // Handle reset to home transform animation.
  void _onAnimateReset() {
    setState(() {
      _transform = _animationReset.value;
    });
    if (!_controllerReset.isAnimating) {
      _animationReset?.removeListener(_onAnimateReset);
      _animationReset = null;
      _controllerReset.reset();
      widget.onResetEnd();
    }
  }

  // Initialize the reset to home transform animation.
  void _animateResetInitialize() {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transform,
      end: _initialTransform,
    ).animate(_controllerReset);
    _controllerReset.duration = const Duration(milliseconds: 400);
    _animationReset.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

  // Stop a running reset to home transform animation.
  void _animateResetStop() {
    _controllerReset.stop();
    _animationReset?.removeListener(_onAnimateReset);
    _animationReset = null;
    _controllerReset.reset();
    widget.onResetEnd();
  }

  @override
  void dispose() {
    _controller.dispose();
    _controllerReset.dispose();
    super.dispose();
  }
}
