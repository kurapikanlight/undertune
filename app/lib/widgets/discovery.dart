import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import 'loading.dart';
import 'branding.dart';

class Discovery extends StatefulWidget {
  const Discovery({
    super.key,
    required this.library,
    required this.extractor,
    required this.row,
    this.active = true,
  });
  final Library library;
  final Extractor extractor;
  final Widget Function(Track, List<Track>) row;
  final bool active;
  @override
  State<Discovery> createState() => _DiscoveryState();
}

class _DiscoveryState extends State<Discovery> {
  static const genres = [
    'Ambient',
    'Alternative',
    'Classical',
    'Darkwave',
    'Electronic',
    'Hip-hop',
    'Indie',
    'Jazz',
    'Lo-fi',
    'Metal',
    'Pop',
    'R&B',
    'Rock',
  ];
  List<Track> _tracks = [];
  String _seedKey = '';
  int _generation = 0;
  bool _loading = false, _failed = false;
  @override
  void initState() {
    super.initState();
    widget.library.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(Discovery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _refresh();
  }

  List<String> get _artists =>
      [...widget.library.history, ...widget.library.liked]
          .where((t) => !t.video && t.artist.trim().isNotEmpty)
          .map((t) => t.artist.trim())
          .toSet()
          .take(3)
          .toList();

  List<String> get _seeds {
    if (widget.library.genres.isNotEmpty) {
      return widget.library.genres.take(3).map((g) => '$g music').toList();
    }
    final artists = _artists;
    return artists.isEmpty
        ? ['new music releases', 'chill music discoveries']
        : artists.map((a) => '$a music').toList();
  }

  Future<void> _refresh({bool force = false}) async {
    if (!widget.active) return;
    final seeds = _seeds;
    final key = seeds.join('|');
    if (!force && key == _seedKey) return;
    final changed = key != _seedKey;
    _seedKey = key;
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
        if (changed) _tracks = [];
      });
    }
    var failures = 0;
    final pages = await Future.wait(
      seeds.map((q) async {
        try {
          return (await widget.extractor.search(q)).tracks;
        } catch (_) {
          failures++;
          return <Track>[];
        }
      }),
    );
    if (!mounted || generation != _generation) return;
    final seen = <String>{};
    final mixed = <Track>[];
    // Interleave real results so one genre or artist does not fill the shelf.
    for (var i = 0; i < 24; i++) {
      for (final page in pages) {
        if (i < page.length && !page[i].live && seen.add(page[i].key)) {
          mixed.add(page[i].asVideo(false));
        }
      }
    }
    setState(() {
      _tracks = mixed.take(24).toList();
      _loading = false;
      _failed = failures == seeds.length;
    });
  }

  @override
  void dispose() {
    ++_generation;
    widget.library.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _genre(String? genre, bool selected) async {
    final values = widget.library.genres.toSet();
    if (genre == null) {
      values.clear();
    } else if (selected) {
      values.add(genre);
    } else {
      values.remove(genre);
    }
    try {
      await widget.library.setGenres(values.toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Genre preferences couldn’t be saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(
            'Music suggestions',
            style: Theme.of(context).textTheme.titleLarge?.merge(
              feelfreeHeadingStyle.copyWith(fontSize: 36),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Genre'),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All music'),
                selected: widget.library.genres.isEmpty,
                onSelected: (_) => _genre(null, true),
              ),
              for (final genre in genres) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(genre),
                  selected: widget.library.genres.contains(genre),
                  onSelected: (value) => _genre(genre, value),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Text(
            'Based on your taste',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_loading && _tracks.isEmpty)
          const ContentSkeleton(
            count: 3,
            artworkSize: 64,
            horizontalPadding: 20,
            verticalPadding: 4,
            artworkGap: 10,
            titleLines: 2,
          ),
        ..._tracks.map((t) => widget.row(t, _tracks)),
        if (_failed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('Music suggestions couldn’t load.')),
                TextButton(
                  onPressed: () => _refresh(force: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        if (!_loading && !_failed && _tracks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Try another genre to find more music.'),
          ),
      ],
    );
  }
}
