import 'dart:async';
import 'package:flutter/material.dart';
import '../media/downloads.dart';
import '../widgets/track_row.dart';
import '../widgets/branding.dart';
import '../widgets/loading.dart';
import '../library.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.downloads,
    required this.library,
    required this.onPlay,
  });
  final Downloads downloads;
  final Library library;
  final void Function(DownloadEntry) onPlay;
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  Future<void> _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ListenableBuilder(
          listenable: widget.library,
          builder: (c, _) {
            final library = widget.library;
            Widget choice<T>(
              String label,
              T value,
              Map<T, String> options,
              Future<void> Function(T) save,
            ) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<T>(
                value: value,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                ),
                items: options.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  try {
                    await save(v);
                  } catch (error) {
                    if (c.mounted) {
                      ScaffoldMessenger.of(
                        c,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Download settings',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                choice(
                  'Download type',
                  library.downloadType,
                  const {'audio': 'Audio', 'video': 'Video'},
                  (v) => library.setDownloadPreferences(type: v),
                ),
                choice(
                  'Audio quality',
                  library.downloadAudioBitrate,
                  const {
                    0: 'Best available',
                    160: 'Up to 160 kbps',
                    128: 'Up to 128 kbps',
                    64: 'Up to 64 kbps',
                  },
                  (v) => library.setDownloadPreferences(audioBitrate: v),
                ),
                choice(
                  'Video quality',
                  library.downloadVideoHeight,
                  const {
                    0: 'Best available',
                    1080: 'Up to 1080p',
                    720: 'Up to 720p',
                    480: 'Up to 480p',
                    360: 'Up to 360p',
                  },
                  (v) => library.setDownloadPreferences(videoHeight: v),
                ),
                const Text(
                  'Uses the closest available source at or below your choice, or the lowest available if none fits. Changes apply to new downloads. Audio playback always uses the highest available bitrate.',
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    widget.downloads.refresh();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => widget.downloads.refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Downloads',
          style: feelfreeHeadingStyle.copyWith(fontSize: 36),
        ),
        actions: [
          IconButton(
            tooltip: 'Download settings',
            onPressed: _settings,
            icon: const Icon(
              Icons.settings_outlined,
              semanticLabel: 'Download settings',
            ),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Audio'),
            Tab(text: 'Video'),
          ],
        ),
      ),
      body: TabBarView(children: [_list('audio'), _list('video')]),
    ),
  );

  Widget _list(String kind) => ListenableBuilder(
    listenable: widget.downloads,
    builder: (context, _) {
      final entries = widget.downloads.entries
          .where((e) => e.kind == kind)
          .toList();
      return RefreshIndicator(
        onRefresh: widget.downloads.refresh,
        child: ListView(
          key: PageStorageKey('downloads-$kind'),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 16,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.downloads.error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Downloads couldn’t refresh. Check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: widget.downloads.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (!widget.downloads.hasLoaded && widget.downloads.loading)
              const ContentSkeleton(
                count: 4,
                horizontalPadding: 16,
                verticalPadding: 10,
                artworkGap: 16,
                actionWidth: 48,
                label: 'Loading downloads',
              )
            else if (entries.isEmpty && widget.downloads.error == null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text('No $kind downloads yet.'),
                    const SizedBox(height: 8),
                    Text(
                      'Choose $kind in Download settings, then download from an item’s menu.',
                    ),
                  ],
                ),
              ),
            ...entries.map(
              (e) => ListTile(
                leading: Artwork(e.track.artwork),
                title: Text(
                  e.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${e.kind == 'video' ? 'Video' : 'Audio'}${e.quality.isEmpty ? '' : ' · ${e.quality}'} · ${e.status == 'complete'
                      ? 'Available offline'
                      : e.status == 'downloading' && e.total > 0
                      ? 'Downloading · ${(100 * e.bytes / e.total).round()}%'
                      : e.status}',
                ),
                onTap: e.localUrl == null ? null : () => widget.onPlay(e),
                trailing: IconButton(
                  tooltip: 'Remove download',
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Remove download?'),
                        content: const Text(
                          'This removes the downloaded file. Your playlists and likes remain.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await widget.downloads.remove(e.id);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
