import 'framework.dart';

/// Breakpoint used in [SlotLayout] and [AdaptiveScaffold].
abstract class Breakpoint {
  /// Returns a [Breakpoint].
  const Breakpoint();
  /// Whether the breakpoint is active under some conditions related to the
  /// context of the screen.
  bool isActive(BuildContext context);
}
