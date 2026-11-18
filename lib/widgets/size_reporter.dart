import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Signale la hauteur de son enfant après chaque mise en page.
class SizeReporter extends SingleChildRenderObjectWidget {
  const SizeReporter({super.key, required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSizeReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderSizeReporter renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class RenderSizeReporter extends RenderProxyBox {
  RenderSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h != _last) {
      _last = h;
      // Après la mise en page : on ne peut pas changer l'état pendant.
      WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
    }
  }
}
