// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_platform_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android', () {
    late FakeAndroidPlatformViewsController viewsController;
    setUp(() {
      viewsController = FakeAndroidPlatformViewsController();
    });

    test('create Android view of unregistered type', () async {
      await expectLater(() => (
        PlatformViewsService.initAndroidView(
          id: 0,
          viewType: 'web',
          layoutDirection: TextDirection.ltr,
        )..setInitialSize(const Size(100.0, 100.0))).create(),
        throwsA(isA<PlatformException>()),
      );
      viewsController.registerViewType('web');

      try {
        await (PlatformViewsService.initSurfaceAndroidView(
          id: 0,
          viewType: 'web',
          layoutDirection: TextDirection.ltr,
        )..setInitialSize(const Size(1.0, 1.0))).create();
      } catch (e) {
        expect(false, isTrue, reason: 'did not expected any exception, but instead got `$e`');
      }

      try {
        await (PlatformViewsService.initAndroidView(
          id: 1,
          viewType: 'web',
          layoutDirection: TextDirection.ltr,
        )..setInitialSize(const Size(1.0, 1.0))).create();
      } catch (e) {
        expect(false, isTrue, reason: 'did not expected any exception, but instead got `$e`');
      }
    });

    test('create Android views', () async {
      viewsController.registerViewType('webview');
      await (PlatformViewsService.initAndroidView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr)
          ..setInitialSize(const Size(100.0, 100.0))).create();
      await (PlatformViewsService.initAndroidView( id: 1, viewType: 'webview', layoutDirection: TextDirection.rtl)
          ..setInitialSize(const Size(200.0, 300.0))).create();
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
          const FakeAndroidPlatformView(1, 'webview', Size(200.0, 300.0), AndroidViewController.kAndroidLayoutDirectionRtl, null),
        ]),
      );
    });

    test('reuse Android view id', () async {
      viewsController.registerViewType('webview');
      final AndroidViewController controller = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      controller.setInitialSize(const Size(100.0, 100.0));
      await controller.create();
      expectLater(
        () {
          final AndroidViewController controller = PlatformViewsService.initAndroidView(
            id: 0,
            viewType: 'web',
            layoutDirection: TextDirection.ltr,
          )..setInitialSize(const Size(100.0, 100.0));
          return controller.create();
        },
        throwsA(isA<PlatformException>()),
      );
    });

    test('dispose Android view', () async {
      viewsController.registerViewType('webview');
      await (PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(100.0, 100.0))).create();

      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(200.0, 300.0));
      await viewController.create();
      await viewController.dispose();

      final AndroidViewController surfaceViewController = PlatformViewsService.initSurfaceAndroidView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(200.0, 300.0));
      await surfaceViewController.create();
      await surfaceViewController.dispose();

      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
        ]),
      );
    });

    test('dispose Android view twice', () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(200.0, 300.0));
      await viewController.create();
      await viewController.dispose();
      await viewController.dispose();
    });

    test('dispose clears focusCallbacks', () async {
      bool didFocus = false;
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
        onFocus: () { didFocus = true; },
      )..setInitialSize(const Size(100.0, 100.0));
      await viewController.create();
      await viewController.dispose();
      final ByteData message =
          SystemChannels.platform_views.codec.encodeMethodCall(const MethodCall('viewFocused', 0));
      await SystemChannels.platform_views.binaryMessenger.handlePlatformMessage(SystemChannels.platform_views.name, message, (_) { });
      expect(didFocus, isFalse);
    });

    test('resize Android view', () async {
      viewsController.registerViewType('webview');
      await (PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(100.0, 100.0))).create();

      final AndroidViewController androidView = PlatformViewsService.initAndroidView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(200.0, 300.0));
      await androidView.create();
      await androidView.setSize(const Size(500.0, 500.0));

      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
          const FakeAndroidPlatformView(1, 'webview', Size(500.0, 500.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
        ]),
      );
    });

    test('OnPlatformViewCreated callback', () async {
      viewsController.registerViewType('webview');
      final List<int> createdViews = <int>[];
      void callback(int id) { createdViews.add(id); }

      final AndroidViewController controller1 = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..addOnPlatformViewCreatedListener(callback);
      expect(createdViews, isEmpty);

      controller1.setInitialSize(const Size(100.0, 100.0));
      await controller1.create();
      expect(createdViews, orderedEquals(<int>[0]));

      final AndroidViewController controller2 = PlatformViewsService.initAndroidView(
        id: 5,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..addOnPlatformViewCreatedListener(callback);
      expect(createdViews, orderedEquals(<int>[0]));

      controller2.setInitialSize(const Size(100.0, 200.0));
      await controller2.create();
      expect(createdViews, orderedEquals(<int>[0, 5]));

    });

    test("change Android view's directionality before creation", () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.rtl,
      )..setInitialSize(const Size(100.0, 100.0));
      await viewController.setLayoutDirection(TextDirection.ltr);
      await viewController.create();
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionLtr, null),
        ]),
      );
    });

    test("change Android view's directionality after creation", () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(100.0, 100.0));
      await viewController.setLayoutDirection(TextDirection.rtl);
      await viewController.create();
      expect(
        viewsController.views,
        unorderedEquals(<FakeAndroidPlatformView>[
          const FakeAndroidPlatformView(0, 'webview', Size(100.0, 100.0), AndroidViewController.kAndroidLayoutDirectionRtl, null),
        ]),
      );
    });

    test("set Android view's offset if view is created", () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 7,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      )..setInitialSize(const Size(100.0, 100.0));
      await viewController.create();
      await viewController.setOffset(const Offset(10, 20));
      expect(
        viewsController.offsets,
        equals(<int, Offset>{
          7: const Offset(10, 20),
        }),
      );
    });

    test("doesn't set Android view's offset if view isn't created", () async {
      viewsController.registerViewType('webview');
      final AndroidViewController viewController = PlatformViewsService.initAndroidView(
        id: 7,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      await viewController.setOffset(const Offset(10, 20));
      expect(viewsController.offsets, equals(<int, Offset>{}));
    });
  });

  group('iOS', () {
    late FakeIosPlatformViewsController viewsController;
    setUp(() {
      viewsController = FakeIosPlatformViewsController();
    });

    test('create iOS view of unregistered type', () async {
      expect(
        () {
          return PlatformViewsService.initUiKitView(
            id: 0,
            viewType: 'web',
            layoutDirection: TextDirection.ltr,
          );
        },
        throwsA(isA<PlatformException>()),
      );
    });

    test('create iOS views', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      await PlatformViewsService.initUiKitView(id: 1, viewType: 'webview', layoutDirection: TextDirection.rtl);
      expect(
        viewsController.views,
        unorderedEquals(<FakeUiKitView>[
          const FakeUiKitView(0, 'webview'),
          const FakeUiKitView(1, 'webview'),
        ]),
      );
    });

    test('reuse iOS view id', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(
        id: 0,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      expect(
        () => PlatformViewsService.initUiKitView(id: 0, viewType: 'web', layoutDirection: TextDirection.ltr),
        throwsA(isA<PlatformException>()),
      );
    });

    test('dispose iOS view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      final UiKitViewController viewController = await PlatformViewsService.initUiKitView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );

      viewController.dispose();
      expect(
        viewsController.views,
        unorderedEquals(<FakeUiKitView>[
          const FakeUiKitView(0, 'webview'),
        ]),
      );
    });

    test('dispose inexisting iOS view', () async {
      viewsController.registerViewType('webview');
      await PlatformViewsService.initUiKitView(id: 0, viewType: 'webview', layoutDirection: TextDirection.ltr);
      final UiKitViewController viewController = await PlatformViewsService.initUiKitView(
        id: 1,
        viewType: 'webview',
        layoutDirection: TextDirection.ltr,
      );
      await viewController.dispose();
      expect(
        () async {
          await viewController.dispose();
        },
        throwsA(isA<PlatformException>()),
      );
    });
  });

  test('toString works as intended', () async {
    const AndroidPointerProperties androidPointerProperties = AndroidPointerProperties(id: 0, toolType: 0);
    expect(androidPointerProperties.toString(), 'AndroidPointerProperties(id: 0, toolType: 0)');

    const double zero = 0.0;
    const AndroidPointerCoords androidPointerCoords = AndroidPointerCoords(
      orientation: zero,
      pressure: zero,
      size: zero,
      toolMajor: zero,
      toolMinor: zero,
      touchMajor: zero,
      touchMinor: zero,
      x: zero,
      y: zero
    );
    expect(androidPointerCoords.toString(), 'AndroidPointerCoords(orientation: $zero, '
      'pressure: $zero, '
      'size: $zero, '
      'toolMajor: $zero, '
      'toolMinor: $zero, '
      'touchMajor: $zero, '
      'touchMinor: $zero, '
      'x: $zero, '
      'y: $zero)',
    );

    final AndroidMotionEvent androidMotionEvent = AndroidMotionEvent(
      downTime: 0,
      eventTime: 0,
      action: 0,
      pointerCount: 0,
      pointerProperties: <AndroidPointerProperties>[],
      pointerCoords: <AndroidPointerCoords>[],
      metaState: 0,
      buttonState: 0,
      xPrecision: zero,
      yPrecision: zero,
      deviceId: 0,
      edgeFlags: 0,
      source: 0,
      flags: 0,
      motionEventId: 0
    );
    expect(androidMotionEvent.toString(), 'AndroidPointerEvent(downTime: 0, '
      'eventTime: 0, '
      'action: 0, '
      'pointerCount: 0, '
      'pointerProperties: [], '
      'pointerCoords: [], '
      'metaState: 0, '
      'buttonState: 0, '
      'xPrecision: $zero, '
      'yPrecision: $zero, '
      'deviceId: 0, '
      'edgeFlags: 0, '
      'source: 0, '
      'flags: 0, '
      'motionEventId: 0)',
    );
  });
}
