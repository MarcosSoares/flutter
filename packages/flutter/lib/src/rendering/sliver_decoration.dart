// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'object.dart';
import 'proxy_sliver.dart';
import 'sliver.dart';

/// Paints a [Decoration] either before or after its child paints.
class RenderSliverDecoration extends RenderProxySliver {
  /// Creates a decorated sliver.
  ///
  /// The [decoration], [position], and [configuration] arguments must not be
  /// null. By default the decoration paints behind the child.
  ///
  /// The [ImageConfiguration] will be passed to the decoration (with the size
  /// filled in) to let it resolve images.
  RenderSliverDecoration({
    required Decoration decoration,
    DecorationPosition position = DecorationPosition.background,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) : _decoration = decoration,
       _position = position,
       _configuration = configuration;

  /// What decoration to paint.
  ///
  /// Commonly a [BoxDecoration].
  Decoration get decoration => _decoration;
  Decoration _decoration;
  set decoration(Decoration value) {
    if (value == decoration) {
      return;
    }
    _decoration = value;
    _painter?.dispose();
    _painter = decoration.createBoxPainter(markNeedsPaint);
    markNeedsPaint();
  }

  /// Whether to paint the box decoration behind or in front of the child.
  DecorationPosition get position => _position;
  DecorationPosition _position;
  set position(DecorationPosition value) {
    if (value == position) {
      return;
    }
    _position = value;
    markNeedsPaint();
  }

  /// The settings to pass to the decoration when painting, so that it can
  /// resolve images appropriately. See [ImageProvider.resolve] and
  /// [BoxPainter.paint].
  ///
  /// The [ImageConfiguration.textDirection] field is also used by
  /// direction-sensitive [Decoration]s for painting and hit-testing.
  ImageConfiguration get configuration => _configuration;
  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == configuration) {
      return;
    }
    _configuration = value;
    markNeedsPaint();
  }

  BoxPainter? _painter;

  @override
  void attach(covariant PipelineOwner owner) {
    _painter = decoration.createBoxPainter(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null && child!.geometry!.visible) {
      final SliverPhysicalParentData childParentData = child!.parentData! as SliverPhysicalParentData;
      final Size childSize;
      final Offset scrollOffset;
      switch (constraints.axis) {
        case Axis.vertical:
          childSize = Size(constraints.crossAxisExtent, child!.geometry!.scrollExtent);
          scrollOffset = Offset(0.0, -constraints.scrollOffset);
        case Axis.horizontal:
          childSize = Size(child!.geometry!.scrollExtent, constraints.crossAxisExtent);
          scrollOffset = Offset(-constraints.scrollOffset, 0.0);
      }
      final Offset childOffset = offset + childParentData.paintOffset;
      if (position == DecorationPosition.background) {
        _painter!.paint(context.canvas, childOffset + scrollOffset, configuration.copyWith(size: childSize));
      }
      context.paintChild(child!, childOffset);
      if (position == DecorationPosition.foreground) {
        _painter!.paint(context.canvas, childOffset + scrollOffset, configuration.copyWith(size: childSize));
      }
    }
  }
}
