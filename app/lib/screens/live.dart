import 'dart:async';
import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../widgets/video_card.dart';
import '../widgets/loading.dart';

/// Saved broadcasts are checked again on entry, resume, and every minute.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.library,
    required this.extractor,
    required this.onPlay,
    required this.onActions,
    required this.onAdd,
  });
  final Library library;
  final Extractor extractor;
  final ValueChanged<Track> onPlay;
  final Future<void> Function(Track) onActions;
  final VoidCallback onAdd;
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with WidgetsBindingObserver {
  Timer? _timer;
  final _ongoing = <String>{};
  String _keys = '';
  int _generation = 0;
  bool _checking = false, _failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
      _generation++;
      _ongoing.clear();
    }
  }

  @override
  void didUpdateWidget(LiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_keys != widget.library.liveStreams.map((t) => t.key).join('|')) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final streams = List<Track>.of(widget.library.liveStreams);
    _keys = streams.map((t) => t.key).join('|');
    setState(() {
      _checking = true;
      _failed = false;
      _ongoing.clear();
    });
    final valid = <String>{};
    var failed = false;
    await Future.wait(
      streams.map((track) async {
        try {
          final info = await widget.extractor.resolve(track);
          if (!mounted || generation != _generation) return;
          if (info['live'] == true) {
            valid.add(track.key);
          } else if (info['live'] == false) {
            await widget.library.removeLive(track);
          } else {
            failed = true;
          }
        } catch (_) {
          failed = true;
        }
      }),
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _ongoing.addAll(valid);
      _checking = false;
      _failed = failed;
    });
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save ongoing broadcasts here from a video’s Add to Live action.',
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Find live streams'),
              ),
            ],
          ),
        ),
        if (_checking && widget.library.liveStreams.isNotEmpty)
          ContentSkeleton(
            video: true,
            count: widget.library.liveStreams.length.clamp(1, 2),
            label: 'Checking live streams',
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Some streams couldn’t be checked. Pull down to retry.',
                ),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          ),
        if (!_checking && !_failed && _ongoing.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No ongoing live streams saved.'),
          ),
        for (final t in widget.library.liveStreams.where(
          (t) => _ongoing.contains(t.key),
        ))
          VideoCard(
            track: t,
            onTap: () => widget.onPlay(t),
            onMore: () => widget.onActions(t),
          ),
      ],
    ),
  );
}
