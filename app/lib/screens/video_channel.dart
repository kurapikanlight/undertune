import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/video_catalog.dart';
import '../widgets/branding.dart';
import '../widgets/loading.dart';
import '../widgets/media_image.dart';
import '../widgets/video_catalog_widgets.dart';

class VideoChannelScreen extends StatefulWidget {
  const VideoChannelScreen({
    super.key,
    required this.channel,
    required this.library,
    required this.catalog,
    required this.row,
    required this.onPlaylist,
  });
  final VideoChannel channel;
  final Library library;
  final VideoCatalog catalog;
  final Widget Function(Track, List<Track>) row;
  final ValueChanged<RemoteVideoPlaylist> onPlaylist;
  @override
  State<VideoChannelScreen> createState() => _VideoChannelScreenState();
}

class _VideoChannelScreenState extends State<VideoChannelScreen> {
  late VideoChannel _channel = widget.channel;
  final _scroll = ScrollController();
  List<Track> _videos = [];
  List<RemoteVideoPlaylist> _playlists = [];
  String _tab = 'videos', _sort = 'latest';
  String? _next, _error;
  bool _metadata = false, _loading = true, _following = false;
  late final bool _knownIdentity;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _knownIdentity = widget.library.isFollowing(widget.channel);
    _scroll.addListener(_paginate);
    _loadChannel();
  }

  void _paginate() {
    if (_scroll.position.extentAfter < 600 &&
        !_loading &&
        _next != null &&
        _error == null) {
      _load(more: true);
    }
  }

  Future<void> _loadChannel() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final channel = await widget.catalog.channel(widget.channel);
      if (!mounted) return;
      setState(() {
        _channel = channel;
        _metadata = true;
      });
      if (!channel.tabs.contains(_tab)) {
        if (channel.tabs.contains('playlists')) {
          _tab = 'playlists';
        } else {
          setState(() => _loading = false);
          return;
        }
      }
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Couldn’t load this channel.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _load({bool more = false, bool refresh = false}) async {
    if (more && (_loading || _next == null)) return;
    final generation = ++_generation;
    final token = more ? _next : null;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _videos = [];
        _playlists = [];
        _next = null;
      }
    });
    try {
      final result = await widget.catalog.channelItems(
        _channel,
        tab: _tab,
        sort: _sort,
        page: token,
        refresh: refresh,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      final videoKeys = _videos.map((v) => v.key).toSet();
      final playlistKeys = _playlists.map((p) => p.key).toSet();
      setState(() {
        _videos.addAll(result.videos.where((v) => videoKeys.add(v.key)));
        _playlists.addAll(
          result.playlists.where((p) => playlistKeys.add(p.key)),
        );
        _next = result.nextPage;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        if (videoPageExpired(error)) _next = null;
        setState(
          () => _error = _sort == 'popular'
              ? 'Popular videos aren’t available right now. Try Latest or retry.'
              : 'Couldn’t load this list.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(String tab, String sort) {
    if (_tab == tab && _sort == sort) return;
    setState(() {
      _tab = tab;
      _sort = sort;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  Future<void> _follow() async {
    setState(() => _following = true);
    try {
      await widget.library.setFollowing(
        _channel,
        !widget.library.isFollowing(_channel),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save following. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _tab == 'videos' ? _videos.length : _playlists.length;
    return ListView.builder(
      key: ValueKey('channel-${widget.channel.key}'),
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: count + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _header(context);
        if (index <= count) {
          return _tab == 'videos'
              ? widget.row(_videos[index - 1], _videos)
              : VideoPlaylistRow(
                  playlist: _playlists[index - 1],
                  saved: widget.library.hasVideoPlaylist(_playlists[index - 1]),
                  onTap: () => widget.onPlaylist(_playlists[index - 1]),
                );
        }
        if (_loading) {
          return _tab == 'videos'
              ? const ContentSkeleton(video: true, count: 2)
              : const CatalogSkeleton();
        }
        if (_error != null) {
          return CatalogMessage(
            message: _error!,
            onRetry: () => _metadata
                ? _load(more: _next != null, refresh: true)
                : _loadChannel(),
          );
        }
        if (count == 0) {
          return CatalogMessage(
            message: _tab == 'videos'
                ? 'No videos available on this channel.'
                : 'No public playlists available.',
          );
        }
        if (_next != null) {
          return TextButton(
            onPressed: () => _load(more: true),
            child: const Text('Load more'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _header(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_channel.banner.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3.5,
              child: MediaImage.network(
                _channel.banner,
                cacheWidth: artworkDecodeWidth(
                  context,
                  MediaQuery.sizeOf(context).width,
                ),
                fallback: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(
          children: [
            ChannelAvatar(channel: _channel, size: 76),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MediaHeading(_channel.name, fontSize: 38, maxLines: 2),
                  if (_channel.subscribers >= 0)
                    Text(
                      '${compactCount(_channel.subscribers)} subscribers',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_metadata && _loading)
              const SkeletonPulse(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SkeletonBlock(height: 32),
                ),
              )
            else if (_channel.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _channel.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ListenableBuilder(
              listenable: widget.library,
              builder: (context, _) {
                final followed = widget.library.isFollowing(_channel);
                return FilledButton.tonalIcon(
                  onPressed: (!_metadata && !_knownIdentity) || _following
                      ? null
                      : _follow,
                  icon: Icon(
                    followed ? Icons.check_rounded : Icons.add_rounded,
                  ),
                  label: Text(followed ? 'Following' : 'Follow'),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 5, bottom: 12),
              child: Text(
                'Following is saved in Undertune only.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_metadata &&
                _channel.tabs.contains('playlists') &&
                _channel.tabs.contains('videos'))
              DefaultTabController(
                length: 2,
                initialIndex: _tab == 'videos' ? 0 : 1,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.label,
                  onTap: (index) =>
                      _select(index == 0 ? 'videos' : 'playlists', 'latest'),
                  tabs: const [
                    Tab(text: 'Videos'),
                    Tab(text: 'Playlists'),
                  ],
                ),
              ),
            if (_metadata &&
                _tab == 'videos' &&
                _channel.tabs.contains('videos'))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Latest'),
                      showCheckmark: false,
                      selected: _sort == 'latest',
                      onSelected: (_) => _select('videos', 'latest'),
                    ),
                    ChoiceChip(
                      label: const Text('Popular'),
                      showCheckmark: false,
                      selected: _sort == 'popular',
                      onSelected: _channel.sorts.contains('popular')
                          ? (_) => _select('videos', 'popular')
                          : null,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ],
  );
}
