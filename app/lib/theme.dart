import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Atmosphere {
  const Atmosphere(
    this.id,
    this.name,
    this.canvas,
    this.clouds,
    this.accent,
    this.surface, {
    this.light = false,
  });
  final String id, name;
  final Color canvas, accent, surface;
  final List<Color> clouds;
  final bool light;
  Color get text => light ? const Color(0xff151d32) : Colors.white;
  static const all = [
    Atmosphere(
      'midnight_bloom',
      'Sienna',
      Color(0xff000080),
      [Color(0xff2443a8), Color(0xff0b6078), Color(0xff2443a8)],
      Color(0xff67e8f9),
      Color(0xff0b2233),
    ),
    Atmosphere(
      'pastelghost',
      'Amethyst',
      Color(0xff020006),
      [Color(0xff552780), Color(0xff352055), Color(0xff6c447e)],
      Color(0xffc3a0ff),
      Color(0xff191223),
    ),
    Atmosphere(
      'sidewalks',
      'Goth',
      Color(0xff03020a),
      [Color(0xff672c56), Color(0xff37205c), Color(0xff15264a)],
      Color(0xfff09ac0),
      Color(0xff201527),
    ),
    Atmosphere(
      'obsidian',
      'Enter Sandman',
      Colors.black,
      [Color(0xff111216), Color(0xff0a0b10), Color(0xff17171b)],
      Color(0xffbfc6d6),
      Color(0xff0d0e11),
    ),
    Atmosphere(
      'graphite',
      'Requiem',
      Color(0xff020304),
      [Color(0xff32343b), Color(0xff252a31), Color(0xff44454a)],
      Color(0xffcad0da),
      Color(0xff1d2025),
    ),
    Atmosphere(
      'afterglow',
      'Stars',
      Color(0xff020610),
      [Color(0xff101f42), Color(0xff352053), Color(0xff56213f)],
      Color(0xffaeb5ff),
      Color(0xff12172c),
    ),
    Atmosphere(
      'emerald',
      'Heart to Heart',
      Color(0xff020a08),
      [Color(0xff064e3b), Color(0xff065f46), Color(0xff0b3533)],
      Color(0xff34d399),
      Color(0xff0b211b),
    ),
    Atmosphere(
      'daydream',
      'Bad Romance',
      Color(0xffeef4fb),
      [Color(0xffa4c2df), Color(0xfff5f7fd), Color(0xffbac0e5)],
      Color(0xff435a9b),
      Color(0xfff5f7fd),
      light: true,
    ),
  ];
  static Atmosphere byId(String id) =>
      all.firstWhere((e) => e.id == id, orElse: () => all.first);
  static final _themeData = Expando<ThemeData>();
  ThemeData get data => _themeData[this] ??= _buildData();
  ThemeData _buildData() => ThemeData(
    brightness: light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: light ? Brightness.light : Brightness.dark,
      primary: accent,
      surface: surface,
      onSurface: text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: text,
      systemOverlayStyle: systemBarsFor(
        light ? Brightness.light : Brightness.dark,
      ),
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: canvas.withValues(alpha: .94),
      indicatorColor: accent.withValues(alpha: .17),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: text,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: text,
      ),
    ),
    dividerColor: text.withValues(alpha: .08),
    sliderTheme: SliderThemeData(
      activeTrackColor: text,
      thumbColor: text,
      inactiveTrackColor: text.withValues(alpha: .22),
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
    ),
    useMaterial3: true,
  );
}

class PlaylistThemePicker extends StatelessWidget {
  const PlaylistThemePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Playlist theme',
      helperText: 'Applies to this playlist and its Now Playing screen.',
      helperMaxLines: 3,
    ),
    items: [
      const DropdownMenuItem(
        value: '',
        child: Text(
          'Follow app theme',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      for (final theme in Atmosphere.all)
        DropdownMenuItem(
          value: theme.id,
          child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged == null ? null : (value) => onChanged!(value!),
  );
}

class PlaylistThemeScope extends StatelessWidget {
  const PlaylistThemeScope({
    super.key,
    required this.themeId,
    required this.child,
  });
  final String? themeId;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Atmosphere.all.where((t) => t.id == themeId).firstOrNull;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);
    return AnimatedTheme(
      data: theme?.data ?? Theme.of(context),
      duration: theme == null ? Duration.zero : duration,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: duration,
              child: theme == null
                  ? const SizedBox.shrink()
                  : AtmosphericBackground(
                      theme: theme,
                      child: const SizedBox.expand(),
                    ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class AtmosphericBackground extends StatefulWidget {
  const AtmosphericBackground({
    super.key,
    required this.theme,
    required this.child,
  });
  final Atmosphere theme;
  final Widget child;
  @override
  State<AtmosphericBackground> createState() => _AtmosphericBackgroundState();
}

class _AtmosphericBackgroundState extends State<AtmosphericBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // All three cloud periods meet here, so the loop has no phase jump.
  static const _cycleSeconds = 12012; // LCM(28, 33, 39).
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cycleSeconds),
  );
  bool _foreground = true;
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
    if (_foreground &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 350),
          child: SizedBox.expand(
            key: ValueKey(widget.theme.id),
            child: CustomPaint(painter: _Clouds(widget.theme, _motion)),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class _Clouds extends CustomPainter {
  _Clouds(this.theme, this.motion) : super(repaint: motion);
  final Atmosphere theme;
  final Animation<double> motion;
  @override
  void paint(Canvas canvas, Size size) {
    final seconds = motion.value * _AtmosphericBackgroundState._cycleSeconds;
    canvas.drawColor(theme.canvas, BlendMode.src);
    for (var i = 0; i < 3; i++) {
      final phase = seconds * math.pi * 2 / [28, 33, 39][i] + i * 2;
      final center = Offset(
        size.width * (.3 + i * .22 + .18 * math.sin(phase)),
        size.height * (.23 + i * .23 + .12 * math.cos(phase)),
      );
      final radius = size.longestSide * (.66 + .035 * math.sin(phase));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              theme.clouds[i].withValues(alpha: .85),
              theme.clouds[i].withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_Clouds old) => old.theme != theme || old.motion != motion;
}

SystemUiOverlayStyle systemBarsFor(Brightness brightness) =>
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: brightness,
    );

class ThemeSystemBars extends StatelessWidget {
  const ThemeSystemBars({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: systemBarsFor(Theme.of(context).brightness),
    child: child,
  );
}
