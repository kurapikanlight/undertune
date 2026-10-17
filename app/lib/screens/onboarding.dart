import 'package:flutter/material.dart';
import '../library.dart';
import '../theme.dart';
import '../widgets/branding.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.library});
  final Library library;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _typingDuration = Duration(seconds: 1);
  static const _revealDuration = Duration(seconds: 2);
  late final _intro = AnimationController(
    vsync: this,
    duration: _typingDuration + _revealDuration,
  );
  bool _started = false, _choosing = false, _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save your choice. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _welcome() => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) {
                    const command = 'Welcome to';
                    const commandStyle = TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      letterSpacing: .8,
                    );
                    final elapsed =
                        (_intro.value * _intro.duration!.inMilliseconds)
                            .round();
                    final count =
                        (elapsed *
                                command.length ~/
                                _typingDuration.inMilliseconds)
                            .clamp(0, command.length);
                    final cursor =
                        elapsed < _typingDuration.inMilliseconds &&
                            _intro.isAnimating &&
                            (elapsed ~/ 350).isEven
                        ? '▌'
                        : ' ';
                    final progress = Curves.easeInOut.transform(
                      ((elapsed - _typingDuration.inMilliseconds) /
                              _revealDuration.inMilliseconds)
                          .clamp(0, 1),
                    );
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: command,
                          excludeSemantics: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Stack(
                              children: [
                                const Opacity(
                                  opacity: 0,
                                  child: Text(
                                    'Welcome to▌',
                                    style: commandStyle,
                                  ),
                                ),
                                Text(
                                  '${command.substring(0, count)}$cursor',
                                  key: const ValueKey('welcome-command'),
                                  style: commandStyle,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Transform.scale(
                          key: const ValueKey('welcome-zoom'),
                          // Reserve the final size so the 20% zoom stays inside the screen.
                          scale: (1 + .2 * progress) / 1.2,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (rect) => LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: const [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [
                                0,
                                progress,
                                (progress + .22).clamp(0, 1),
                              ],
                            ).createShader(rect),
                            child: Opacity(
                              opacity: progress,
                              child: SizedBox(
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Undertune',
                                    style: feelfreeHeadingStyle.copyWith(
                                      fontSize: 128,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() => _choosing = true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.all(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Start',
                      style: feelfreeHeadingStyle.copyWith(fontSize: 36),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, size: 26),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _themes() => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          children: [
            Text(
              'Choose your preferred theme',
              style: feelfreeHeadingStyle.copyWith(fontSize: 44),
            ),
            const SizedBox(height: 12),
            Text(
              'Make Undertune feel like you. You can change this later in Settings.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            for (final atmosphere in Atmosphere.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  selected: widget.library.themeId == atmosphere.id,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: widget.library.themeId == atmosphere.id
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: widget.library.themeId == atmosphere.id ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () => _save(
                              () => widget.library.setTheme(atmosphere.id),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    atmosphere.canvas,
                                    ...atmosphere.clouds,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: atmosphere.accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                atmosphere.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              widget.library.themeId == atmosphere.id
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving
                ? null
                : () => _save(widget.library.completeOnboarding),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _saving ? 'Saving…' : 'Continue',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_choosing,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) setState(() => _choosing = false);
    },
    child: Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 450),
          child: KeyedSubtree(
            key: ValueKey(_choosing),
            child: _choosing ? _themes() : _welcome(),
          ),
        ),
      ),
    ),
  );
}
