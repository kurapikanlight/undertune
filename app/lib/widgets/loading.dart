import 'package:flutter/material.dart';

/// A quiet, shared pulse for a group of placeholders. No work offstage, in the
/// background, or when the system requests reduced motion.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;
  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final _opacity = Tween(begin: .55, end: 1.0).animate(_curve);
  bool _foreground = true;
  bool _animate = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    _animate =
        _foreground &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (_animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!_animate) {
      _controller.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: _animate
        ? FadeTransition(opacity: _opacity, child: widget.child)
        : widget.child,
  );
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height, this.radius = 8});
  final double? width, height;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _TextShape extends StatelessWidget {
  const _TextShape({this.lines = 1, this.size = 14, this.height = 1.43});
  final int lines;
  final double size, height;
  @override
  Widget build(BuildContext context) {
    final lineHeight = MediaQuery.textScalerOf(context).scale(size) * height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        lines,
        (i) => SizedBox(
          height: lineHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: i == lines - 1 ? .7 : .95,
              child: SkeletonBlock(height: lineHeight * .48, radius: 4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Matches the real track/video rows, including their action space and insets.
/// Callers supply their existing row dimensions rather than a new layout system.
class ContentSkeleton extends StatelessWidget {
  const ContentSkeleton({
    super.key,
    this.video = false,
    this.count = 4,
    this.artworkSize = 52,
    this.horizontalPadding = 24,
    this.verticalPadding = 6,
    this.artworkGap = 12,
    this.artworkRadius = 10,
    this.titleLines = 1,
    this.actionWidth = 96,
    this.label,
  });
  final bool video;
  final int count, titleLines;
  final double artworkSize, horizontalPadding, verticalPadding, artworkGap;
  final double actionWidth, artworkRadius;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? (video ? 'Loading videos' : 'Loading music'),
    liveRegion: true,
    child: ExcludeSemantics(
      child: SkeletonPulse(
        child: Column(
          children: List.generate(
            count,
            (_) => video
                ? _video(context)
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Row(
                      children: [
                        SkeletonBlock(
                          width: artworkSize,
                          height: artworkSize,
                          radius: artworkRadius,
                        ),
                        SizedBox(width: artworkGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TextShape(lines: titleLines, height: 1.25),
                              const SizedBox(height: 4),
                              const _TextShape(size: 12, height: 1.3),
                            ],
                          ),
                        ),
                        SizedBox(width: actionWidth),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _video(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Container(
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonBlock(radius: 10),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 12, 0, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TextShape(lines: 2, size: 15, height: 1.35),
                      SizedBox(height: 5),
                      _TextShape(size: 12),
                    ],
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Search suggestions are text rows, not album rows.
class SuggestionSkeleton extends StatelessWidget {
  const SuggestionSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading search suggestions',
    liveRegion: true,
    child: ExcludeSemantics(
      child: SkeletonPulse(
        child: Column(
          children: [
            for (var i = 0; i < 4; i++)
              const SizedBox(
                height: 56,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      SkeletonBlock(width: 20, height: 20),
                      SizedBox(width: 24),
                      Expanded(child: _TextShape()),
                      SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
