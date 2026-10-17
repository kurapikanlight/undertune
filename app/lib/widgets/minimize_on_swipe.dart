import 'package:flutter/material.dart';

class MinimizeOnSwipe extends StatefulWidget {
  const MinimizeOnSwipe({
    super.key,
    required this.onMinimize,
    required this.child,
  });
  final VoidCallback onMinimize;
  final Widget child;
  @override
  State<MinimizeOnSwipe> createState() => _MinimizeOnSwipeState();
}

class _MinimizeOnSwipeState extends State<MinimizeOnSwipe> {
  double _distance = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: (_) => _distance = 0,
    onVerticalDragUpdate: (d) => _distance += d.delta.dy,
    onVerticalDragEnd: (d) {
      if (_distance > 72 || (_distance > 0 && (d.primaryVelocity ?? 0) > 500)) {
        widget.onMinimize();
      }
      _distance = 0;
    },
    onVerticalDragCancel: () => _distance = 0,
    child: widget.child,
  );
}
