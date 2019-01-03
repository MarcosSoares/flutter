import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' show Vector2;
import 'pan_and_zoom_demo_board.dart';
import 'pan_and_zoom_demo_inertial_motion.dart';

class PanAndZoomDemo extends StatelessWidget {
  const PanAndZoomDemo({Key key}) : super(key: key);

  static const String routeName = '/pan_and_zoom';

  @override
  Widget build(BuildContext context) => PanAndZoom();
}

// TODO Create a maximum size border around the hexagon board
class PanAndZoom extends StatelessWidget {
  static const double HEXAGON_RADIUS = 32.0;
  static const int BOARD_RADIUS = 8;

  @override
  Widget build (BuildContext context) {
    final Board board = Board(
      boardRadius: BOARD_RADIUS,
      hexagonRadius: HEXAGON_RADIUS,
    );
    final BoardPainter painter = BoardPainter(
      board: board,
    );
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: MapInteraction(
        child: CustomPaint(
          size: Size.infinite,
          painter: painter,
        ),
        screenSize: screenSize,
      ),
    );
  }
}

// This StatefulWidget handles all user interaction
class MapInteraction extends StatefulWidget {
  const MapInteraction({
    @required this.child,
    @required this.screenSize,
  });

  final Widget child;
  final Size screenSize;

  @override _MapInteractionState createState() => _MapInteractionState();
}
class _MapInteractionState extends State<MapInteraction> with SingleTickerProviderStateMixin {
  Animation<Point<double>> _animation;
  AnimationController _controller;
  static const double MAX_SCALE = 2.5;
  static const double MIN_SCALE = 0.25;
  Point<double> _offset; // Offset from origin of viewport when scale is 1.0
  Point<double> _translateFrom; // Point where a single translation began
  Point<double> _scaleFocalPoint; // Point where a single translation began
  double _scaleStart = 1.0; // Scale value at start of scaling gesture
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();

    // Start out looking at the center
    // A positive x offset moves the scene right, viewport left.
    // A positive y offset moves the scene down, viewport up.
    _offset = Point<double>(
      widget.screenSize.width / 2,
      widget.screenSize.height / 2,
    );

    _controller = AnimationController(
      vsync: this,
    );
  }

  @override
  Widget build (BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // Necessary when translating off screen
      onScaleEnd: onScaleEnd,
      onScaleStart: onScaleStart,
      onScaleUpdate: onScaleUpdate,
      child: ClipRect(
        child: Transform(
          transform: getTransformationMatrix(),
          child: widget.child,
        ),
      ),
    );
  }

  Matrix4 getTransformationMatrix() {
    // Scaling happens first in matrix multiplication, centered on the origin,
    // while our canvas is at its original position with zero translation.
    final Matrix4 scale = Matrix4(
      _scale, 0, 0, 0,
      0, _scale, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    );

    // Original center of the screen with no transformations applied.
    final Point<double> originalCenterOfScreen = Point<double>(
      widget.screenSize.width / 2,
      widget.screenSize.height / 2,
    );
    // Center after scale has been applied.
    // Imagine the scene scaling underneath the viewport while the viewport
    // stays fixed, then this is the new point under the center of the viewport.
    final Point<double> scaledCenterOfScreen = originalCenterOfScreen * (1 / _scale);
    // Center after scale and offset have been applied.
    final Point<double> finalCenterOfScreen = scaledCenterOfScreen + _offset;
    // Translate the original center of the screen to the final center.
    final Vector2 translationVector = Vector2(
        finalCenterOfScreen.x - originalCenterOfScreen.x,
        finalCenterOfScreen.y - originalCenterOfScreen.y,
    );
    final Matrix4 translate = Matrix4(
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      translationVector.x, translationVector.y, 0, 1,
    );

    return scale * translate;
  }

  // Given a point in screen coordinates, return the point in the scene.
  Offset _fromScreen(Offset screenPoint, Point<double> offset, double scale) {
    // Locate the center of the screen in scene coordinates
    final Offset centerOfScreen = Offset(
      offset.x - widget.screenSize.width / 2,
      offset.y - widget.screenSize.height / 2,
    );
    final Offset fromCenterOfScreen = Offset(
      (screenPoint.dx - widget.screenSize.width / 2) / scale,
      (screenPoint.dy - widget.screenSize.height / 2) / scale,
    );
    return centerOfScreen + fromCenterOfScreen;
  }

  // Handle panning and pinch zooming events
  void onScaleStart(ScaleStartDetails details) {
    _controller.stop();
    setState(() {
      _scaleStart = _scale;
      _translateFrom = Point<double>(details.focalPoint.dx, details.focalPoint.dy);
      _scaleFocalPoint = Point<double>(
        _translateFrom.x / _scale + _offset.x,
        _translateFrom.y / _scale + _offset.y,
      );
    });
  }
  void onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (_scaleStart != null) {
        final Offset focalPointScene = _fromScreen(details.focalPoint, _offset, _scale);
        _scale = _scaleStart * details.scale;
        if (_scale > MAX_SCALE) {
          _scale = MAX_SCALE;
        }
        if (_scale < MIN_SCALE) {
          _scale = MIN_SCALE;
        }

        if (details.scale != 1.0) {
          // While scaling, translate such that the user's fingers stay on the
          // same place in the scene. That means that the focal point of the
          // scale should be on the same place in the scene before and after the
          // scale.
          final Offset focalPointSceneNext = _fromScreen(details.focalPoint, _offset, _scale);
          final Offset nextOffset = Offset(
            _offset.x + focalPointSceneNext.dx - focalPointScene.dx,
            _offset.y + focalPointSceneNext.dy - focalPointScene.dy,
          );
          _offset = Point<double>(
            nextOffset.dx,
            nextOffset.dy,
          );
        }
      }
      if (_translateFrom != null && details.scale == 1.0) {
        // The coordinates given by details.focalPoint are screen coordinates
        // that are not affected by _scale. So, dividing by scale here properly
        // gives us more distance when zoomed out and less when zoomed in so
        // that the point under the user's finger stays constant during a drag.
        _offset = Point<double>(
          _offset.x + (details.focalPoint.dx - _translateFrom.x) / _scale,
          _offset.y + (details.focalPoint.dy - _translateFrom.y) / _scale,
        );
        _translateFrom = Point<double>(
          details.focalPoint.dx,
          details.focalPoint.dy,
        );
      }
    });
  }
  void onScaleEnd(ScaleEndDetails details) {
    setState(() {
      _scaleStart = null;
      _translateFrom = null;
    });

    _animation?.removeListener(_onAnimate);
    _controller.reset();

    // If the scale ended with velocity, animate inertial movement
    final double velocityTotal = details.velocity.pixelsPerSecond.dx.abs()
      + details.velocity.pixelsPerSecond.dy.abs();
    if (velocityTotal == 0) {
      return;
    }

    final InertialMotion inertialMotion = InertialMotion(details.velocity, _offset);
    _animation = Tween<Point<double>>(begin: _offset, end: inertialMotion.finalPosition).animate(_controller);
    _controller.duration = Duration(milliseconds: inertialMotion.duration.toInt());
    _animation.addListener(_onAnimate);
    _controller.fling();
  }

  void _onAnimate() {
    setState(() {
      _offset = _animation.value;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class BoardPainter extends CustomPainter {
  BoardPainter({
    this.board,
  });

  Board board;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint hexagonFillPaint = Paint()
      ..color = Colors.grey[600]
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    void drawBoardPoint(BoardPoint boardPoint) {
      canvas.drawPath(board.getPathForBoardPoint(boardPoint), hexagonFillPaint);
    }

    board.forEach(drawBoardPoint);
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) => false;
}
