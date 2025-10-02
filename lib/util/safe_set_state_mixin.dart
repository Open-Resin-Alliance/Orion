/// A mixin providing a convenience method `safeSetState` that only calls
/// `setState` when the [State] object is still mounted. This removes the need
/// to sprinkle `if (!mounted) return;` guards before every `setState` call in
/// async code.
///
/// Usage:
/// ```dart
/// class MyWidgetState extends State<MyWidget> with SafeSetStateMixin {
///   Future<void> load() async {
///     final data = await fetch();
///     safeSetState(() { /* update fields with data */ });
///   }
/// }
/// ```
///
/// This keeps widget state updates safe after await boundaries.
library;

import 'package:flutter/widgets.dart';

mixin SafeSetStateMixin<T extends StatefulWidget> on State<T> {
  /// Calls [setState] only if still [mounted].
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(fn);
  }
}
