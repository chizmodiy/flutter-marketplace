import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

Widget wrapWithKeyboardDismisser(Widget child) {
  return Listener(
    onPointerDown: (event) {
      final focused = FocusManager.instance.primaryFocus;
      if (focused == null) return;
      final focusContext = focused.context;
      if (focusContext == null) return;
      final renderObject = focusContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final offset = renderObject.localToGlobal(Offset.zero);
      final rect = offset & renderObject.size;
      if (rect.contains(event.position)) return;
      FocusManager.instance.primaryFocus?.unfocus();
    },
    behavior: HitTestBehavior.translucent,
    child: child,
  );
}
