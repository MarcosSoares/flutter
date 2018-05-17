import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('provides a value to the layer tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const AnnotatedRegion<int>(
        child: const SizedBox(width: 100.0, height: 100.0),
        value: 1,
      ),
    );
    final List<Layer> layers = tester.layers;
    final AnnotatedRegionLayer<int> layer = layers.firstWhere((Layer layer) => layer is AnnotatedRegionLayer<int>);
    expect(layer.value, 1);
  });
}
