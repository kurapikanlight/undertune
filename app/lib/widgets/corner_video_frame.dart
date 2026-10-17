import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'app_navigation.dart';

/// Keeps the same video subtree alive when switching between full and floating.
class CornerVideoFrame extends StatefulWidget {
  const CornerVideoFrame({
    super.key,
    required this.minimized,
    required this.child,
  });
  final bool minimized;
  final Widget child;
  @override
  State<CornerVideoFrame> createState() => _CornerVideoFrameState();
}

class _CornerVideoFrameState extends State<CornerVideoFrame> {
  Alignment _corner = Alignment.bottomRight;
  Offset? _drag;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final insets = MediaQuery.paddingOf(context);
      final width = (constraints.maxWidth * .48)
          .clamp(150.0, 220.0)
          .clamp(0.0, (constraints.maxWidth - 24).clamp(0.0, double.infinity));
      final height = width * 9 / 16 + 10;
      const left = 12.0;
      final top = insets.top + 8;
      final right = (constraints.maxWidth - width - 12).clamp(
        left,
        double.infinity,
      );
      final bottom =
          (constraints.maxHeight -
                  insets.bottom -
                  UndertuneNavigation.barHeight -
                  8 -
                  height)
              .clamp(top, double.infinity);
      Offset clamp(Offset p) =>
          Offset(p.dx.clamp(left, right), p.dy.clamp(top, bottom));
      final anchor = Offset(
        _corner.x < 0 ? left : right,
        _corner.y < 0 ? top : bottom,
      );
      final position = clamp(_drag ?? anchor);
      void settle() => setState(() {
        final end = clamp(_drag ?? anchor);
        _corner = Alignment(
          end.dx < (left + right) / 2 ? -1 : 1,
          end.dy < (top + bottom) / 2 ? -1 : 1,
        );
        _drag = null;
      });
      return Stack(
        children: [
          AnimatedPositioned(
            duration:
                !widget.minimized ||
                    _drag != null ||
                    MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: widget.minimized ? position.dx : 0,
            top: widget.minimized ? position.dy : 0,
            right: widget.minimized ? null : 0,
            bottom: widget.minimized ? null : 0,
            width: widget.minimized ? width : null,
            height: widget.minimized ? height : null,
            child: Semantics(
              label: widget.minimized ? 'Floating video' : null,
              customSemanticsActions: widget.minimized
                  ? {
                      for (final entry in const {
                        'top left': Alignment.topLeft,
                        'top right': Alignment.topRight,
                        'bottom left': Alignment.bottomLeft,
                        'bottom right': Alignment.bottomRight,
                      }.entries)
                        CustomSemanticsAction(
                          label: 'Move video to ${entry.key}',
                        ): () => setState(() {
                          _drag = null;
                          _corner = entry.value;
                        }),
                    }
                  : null,
              child: GestureDetector(
                onPanStart: widget.minimized
                    ? (_) => setState(() => _drag = anchor)
                    : null,
                onPanUpdate: widget.minimized
                    ? (d) => setState(
                        () => _drag = clamp((_drag ?? anchor) + d.delta),
                      )
                    : null,
                onPanEnd: widget.minimized ? (_) => settle() : null,
                onPanCancel: widget.minimized ? settle : null,
                child: widget.child,
              ),
            ),
          ),
        ],
      );
    },
  );
}
