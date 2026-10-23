import 'dart:async';
import 'package:flutter/foundation.dart';

/// Session-owned countdown; navigation and media changes do not restart it.
class SleepTimer extends ChangeNotifier {
  SleepTimer({required this.onExpired});
  final Future<void> Function() onExpired;
  Timer? _expiry, _ticker;
  Duration? _remaining;
  Duration? get remaining => _remaining;
  bool get active => _remaining != null;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  void start(Duration duration) {
    if (duration <= Duration.zero || duration > const Duration(hours: 24)) {
      throw ArgumentError.value(duration, 'duration', 'Choose up to 24 hours.');
    }
    if (_disposed) return;
    _clear();
    final generation = ++_generation;
    _remaining = duration;
    error = null;
    _expiry = Timer(duration, () => _expire(generation));
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || generation != _generation) return;
      // tick includes missed intervals, so a delayed callback cannot extend it.
      final left = duration - Duration(seconds: timer.tick);
      _remaining = left > Duration.zero ? left : Duration.zero;
      notifyListeners();
    });
    notifyListeners();
  }

  void _clear() {
    _expiry?.cancel();
    _ticker?.cancel();
    _expiry = _ticker = null;
    _remaining = null;
  }

  void cancel() {
    if (_disposed) return;
    ++_generation;
    _clear();
    error = null;
    notifyListeners();
  }

  Future<void> _expire(int generation) async {
    if (_disposed || generation != _generation) return;
    _clear();
    notifyListeners();
    try {
      await onExpired();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error = 'Couldn’t pause playback. Please pause it manually.';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _clear();
    super.dispose();
  }
}
