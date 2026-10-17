import 'dart:async';
import 'package:flutter/widgets.dart';
import '../library.dart';
import 'downloads.dart';
import 'extractor.dart';

/// Reconciles opted-in music playlists with the existing native download queue.
/// Preparation is sequential; DownloadManager owns transfers after enqueue.
class PlaylistDownloads extends ChangeNotifier with WidgetsBindingObserver {
  PlaylistDownloads(this.library, this.downloads, this.extractor) {
    library.addListener(_sync);
    downloads.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }
  final Library library;
  final Downloads downloads;
  final Extractor extractor;
  final _pending = <String, Track>{};
  final _attempted = <String>{};
  final _failed = <String>{};
  final _saving = <String>{};
  bool changing(String id) => _saving.contains(id);
  Map<String, Track> _wanted = {};
  String? _current;
  bool _draining = false, _disposed = false, _foreground = true;
  Timer? _poll;
  bool get busy => _draining;
  List<Track> tracks(String id) =>
      library.playlistTracks(id).where((t) => !t.live && !t.video).toList();
  Set<String> _keys(String id) => tracks(id).map((t) => t.key).toSet();
  bool preparing(String id) {
    final keys = _keys(id);
    return keys.contains(_current) || _pending.keys.any(keys.contains);
  }

  int completedCount(String id) {
    final keys = _keys(id);
    return downloads.entries
        .where(
          (e) =>
              e.kind == 'audio' &&
              e.status == 'complete' &&
              keys.contains(e.track.key),
        )
        .map((e) => e.track.key)
        .toSet()
        .length;
  }

  int failedCount(String id) {
    final keys = _keys(id);
    return {
      ..._failed,
      ...downloads.entries
          .where(
            (e) =>
                e.kind == 'audio' && {'failed', 'missing'}.contains(e.status),
          )
          .map((e) => e.track.key),
    }.where(keys.contains).length;
  }

  Future<void> downloadAll(String id) => _configure(id, true, retry: true);
  Future<void> setAutomatic(String id, bool enabled) => _configure(id, enabled);
  Future<void> _configure(String id, bool enabled, {bool retry = false}) async {
    if (_saving.contains(id)) return;
    _saving.add(id);
    _changed();
    try {
      if (retry) {
        final keys = _keys(id);
        _attempted.removeAll(keys);
        _failed.removeAll(keys);
      }
      await library.setPlaylistAutoDownload(id, enabled);
    } finally {
      _saving.remove(id);
      _changed();
    }
  }

  void _sync() {
    if (_disposed) return;
    _wanted = {
      for (final id in library.autoDownloadPlaylists)
        for (final track in tracks(id)) track.key: track,
    };
    _attempted.removeWhere((key) => !_wanted.containsKey(key));
    _failed.removeWhere((key) => !_wanted.containsKey(key));
    _pending.removeWhere((key, _) => !_wanted.containsKey(key));
    for (final track in _wanted.values) {
      if (!_attempted.contains(track.key) && track.key != _current) {
        _pending[track.key] = track;
      }
    }
    if (_pending.isNotEmpty && !_draining) unawaited(_drain());
    _changed();
  }

  bool _stored(String key) => downloads.entries.any(
    (e) =>
        e.track.key == key &&
        e.kind == 'audio' &&
        {'complete', 'downloading', 'paused'}.contains(e.status),
  );
  Future<void> _drain() async {
    _draining = true;
    try {
      await downloads.refresh();
      if (_disposed) return;
      if (downloads.error != null) {
        _failed.addAll(_pending.keys);
        _attempted.addAll(_pending.keys);
        _pending.clear();
        return;
      }
      while (!_disposed && _pending.isNotEmpty) {
        final track = _pending.remove(_pending.keys.first)!;
        if (!_wanted.containsKey(track.key)) continue;
        _attempted.add(track.key);
        if (_stored(track.key)) continue;
        _current = track.key;
        _changed();
        try {
          final broken = downloads.entries
              .where(
                (e) =>
                    e.track.key == track.key &&
                    e.kind == 'audio' &&
                    {'failed', 'missing'}.contains(e.status),
              )
              .toList();
          for (final entry in broken) {
            await downloads.remove(entry.id);
          }
          if (_disposed || !_wanted.containsKey(track.key)) continue;
          await downloads.enqueueAudio(
            track,
            extractor,
            preferences: library,
            shouldEnqueue: () => !_disposed && _wanted.containsKey(track.key),
          );
          _failed.remove(track.key);
        } catch (_) {
          // A manual download may have won the native duplicate check meanwhile.
          await downloads.refresh();
          if (!_disposed &&
              _wanted.containsKey(track.key) &&
              !_stored(track.key)) {
            _failed.add(track.key);
          }
        } finally {
          _current = null;
          _changed();
        }
      }
    } finally {
      _draining = false;
      _changed();
    }
  }

  void _changed() {
    if (_disposed) return;
    final active =
        _foreground &&
        downloads.entries.any(
          (e) =>
              e.kind == 'audio' &&
              _wanted.containsKey(e.track.key) &&
              {'downloading', 'paused'}.contains(e.status),
        );
    if (!active) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(downloads.refresh()),
      );
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && library.autoDownloadPlaylists.isNotEmpty) {
      unawaited(downloads.refresh());
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    library.removeListener(_sync);
    downloads.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _pending.clear();
    super.dispose();
  }
}
