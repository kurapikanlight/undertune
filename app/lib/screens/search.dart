import 'dart:async';
import 'package:flutter/material.dart';
import '../library.dart';
import '../media/extractor.dart';
import '../media/search.dart';
import '../media/video_catalog.dart';
import '../media/music_collections.dart';
import '../widgets/music_search_collections.dart';
import '../widgets/video_catalog_widgets.dart';
import '../widgets/loading.dart';
import '../widgets/discovery.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.library,
    required this.extractor,
    required this.row,
    this.suggestionRow,
    this.video = false,
    this.catalog,
    this.onChannel,
    this.onVideoPlaylist,
    this.onMusicCollection,
    this.musicCatalog,
    this.focusRequest = 0,
    this.active = true,
  });
  final MusicCatalog? musicCatalog;
  final ValueChanged<MusicCollection>? onMusicCollection;
  final VideoCatalog? catalog;
  final ValueChanged<VideoChannel>? onChannel;
  final ValueChanged<RemoteVideoPlaylist>? onVideoPlaylist;
  final Library library;
  final Extractor extractor;
  final Widget Function(Track, List<Track>) row;
  final Widget Function(Track, List<Track>)? suggestionRow;
  final bool video, active;
  final int focusRequest;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final MusicCatalog _musicCatalog = widget.musicCatalog ?? MusicCatalog();
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final SearchResults _results = SearchResults(widget.extractor)
    ..addListener(_changed);
  Timer? _debounce;
  List<String> _suggestions = [];
  int _suggestionGeneration = 0;
  bool _discovering = false;
  bool _suggestionLoading = false;
  String _topic = 'All';
  String _videoKind = 'Videos', _catalogQuery = '', _followKeys = '';
  List<VideoChannel> _channels = [];
  List<RemoteVideoPlaylist> _playlists = [];
  List<Track> _followVideos = [];
  String? _catalogNext, _catalogError, _followError;
  bool _catalogLoading = false, _followLoading = false;
  int _catalogGeneration = 0, _followGeneration = 0;

  void _libraryChanged() {
    final keys = widget.library.followedChannels.map((c) => c.key).join('|');
    if (keys != _followKeys) {
      _followKeys = keys;
      if (widget.active && widget.video) _loadFollowed();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadFollowed() async {
    final catalog = widget.catalog;
    if (catalog == null ||
        !widget.active ||
        !_discovering ||
        _videoKind != 'Videos' ||
        _topic != 'All') {
      return;
    }
    final generation = ++_followGeneration;
    final sources = [...widget.library.followedChannels];
    setState(() {
      _followLoading = sources.isNotEmpty;
      _followError = null;
    });
    final result = await catalog.followedVideos(
      sources,
      active: () =>
          mounted &&
          widget.active &&
          _discovering &&
          _videoKind == 'Videos' &&
          _topic == 'All' &&
          generation == _followGeneration,
    );
    if (!mounted || generation != _followGeneration) return;
    setState(() {
      _followVideos = result.videos;
      _followLoading = false;
      if (result.failures > 0) {
        _followError = 'Some followed channels couldn’t load.';
      }
    });
  }

  Future<void> _loadCatalog(String query, {bool more = false}) async {
    if (widget.catalog == null ||
        (more && (_catalogLoading || _catalogNext == null))) {
      return;
    }
    final generation = ++_catalogGeneration;
    final kind = _videoKind;
    final token = more ? _catalogNext : null;
    setState(() {
      _catalogQuery = query;
      _catalogLoading = true;
      _catalogError = null;
      if (!more) {
        _channels = [];
        _playlists = [];
        _catalogNext = null;
      }
    });
    try {
      final result = await widget.catalog!.search(query, kind, page: token);
      if (!mounted || generation != _catalogGeneration) return;
      final channelKeys = _channels.map((c) => c.key).toSet();
      final playlistKeys = _playlists.map((p) => p.key).toSet();
      setState(() {
        _channels.addAll(result.channels.where((c) => channelKeys.add(c.key)));
        _playlists.addAll(
          result.playlists.where((p) => playlistKeys.add(p.key)),
        );
        _catalogNext = result.nextPage;
      });
    } catch (error) {
      if (mounted && generation == _catalogGeneration) {
        if (videoPageExpired(error)) _catalogNext = null;
        setState(() => _catalogError = 'Couldn’t load ${kind.toLowerCase()}.');
      }
    } finally {
      if (mounted && generation == _catalogGeneration) {
        setState(() => _catalogLoading = false);
      }
    }
  }

  void _selectVideoKind(String value) {
    if (_videoKind == value) return;
    ++_catalogGeneration;
    setState(() => _videoKind = value);
    if (value == 'Following' || value == 'Liked videos') {
      _text.clear();
      return;
    }
    if (value == 'Videos') {
      if (_discovering || _text.text.isEmpty) {
        _discover(_topic);
      } else {
        _results.submit(_text.text);
      }
    } else {
      _loadCatalog(
        _text.text.trim().isEmpty
            ? (_topic == 'All' ? 'popular' : _topic)
            : _text.text.trim(),
      );
    }
  }

  void _discover([String topic = 'All']) {
    _discovering = true;
    _topic = topic;
    if (_videoKind == 'Videos') {
      _results.submit(topic == 'All' ? 'popular videos' : '$topic videos');
      if (topic == 'All') _loadFollowed();
    } else if ({'Channels', 'Playlists'}.contains(_videoKind)) {
      _loadCatalog(topic == 'All' ? 'popular' : topic);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    widget.library.addListener(_libraryChanged);
    _followKeys = widget.library.followedChannels.map((c) => c.key).join('|');
    if (widget.video && widget.active) {
      _discover();
    }
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.focusRequest != widget.focusRequest) _focus.requestFocus();
    if (widget.video &&
        widget.active &&
        !old.active &&
        _results.query.isEmpty) {
      _discover();
    }
    if (widget.video && widget.active && !old.active) _loadFollowed();
    if (!widget.active) {
      _focus.unfocus();
      ++_followGeneration;
      _followLoading = false;
    }
  }

  void _suggest(String text) {
    _debounce?.cancel();
    final generation = ++_suggestionGeneration;
    _suggestions = [];
    _suggestionLoading = false;

    setState(() {});
    if (text.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || generation != _suggestionGeneration) return;
      setState(() => _suggestionLoading = true);
      List<String> items;
      try {
        items = await widget.extractor.suggestions(text);
      } catch (_) {
        items = widget.library.searches
            .where((e) => e.toLowerCase().contains(text.toLowerCase()))
            .toList();
      }
      if (mounted && generation == _suggestionGeneration) {
        setState(() {
          _suggestions = items;
          _suggestionLoading = false;
        });
      }
    });
  }

  void _submit(String text) {
    _debounce?.cancel();
    ++_suggestionGeneration;
    _suggestionLoading = false;
    _focus.unfocus();
    _discovering = false;
    _text.text = text;
    if (text.trim().isNotEmpty) {
      unawaited(
        widget.library.searched(text.trim()).catchError((Object error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Search history couldn’t be saved.'),
              ),
            );
          }
        }),
      );
    }
    if (widget.video && widget.catalog != null && _videoKind != 'Videos') {
      if ({'Channels', 'Playlists'}.contains(_videoKind)) {
        _loadCatalog(text.trim().isEmpty ? 'popular' : text.trim());
      }
    } else {
      _results.submit(text);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.library.removeListener(_libraryChanged);
    ++_catalogGeneration;
    ++_followGeneration;
    _results.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final found = _results.tracks.map((t) => t.asVideo(widget.video)).toList();
    final queue =
        widget.video &&
            _discovering &&
            _topic == 'All' &&
            _videoKind == 'Videos'
        ? blendVideoSuggestions(
            found,
            _followVideos,
            widget.library.history
                .where((t) => t.video)
                .map((t) => t.key)
                .toSet(),
          )
        : found;
    final showCollections =
        !widget.video &&
        widget.onMusicCollection != null &&
        _results.query.isNotEmpty &&
        (queue.isNotEmpty || !_results.loading);
    final collectionIndex = queue.length < 3 ? queue.length + 1 : 4;
    final collectionKey = ValueKey('music-collections:${_results.query}');
    final suggestions = _text.text.isEmpty
        ? widget.library.searches
        : _suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          child: TextField(
            controller: _text,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: _suggest,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: widget.video
                  ? (_videoKind == 'Following'
                        ? 'Search followed channels'
                        : 'Search ${_videoKind.toLowerCase()}')
                  : 'Songs, artists, and more',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _text.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _text.clear();
                        _suggest('');
                        if (widget.video) {
                          _discover();
                        } else {
                          _results.submit('');
                        }
                      },
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (widget.video && !focused && widget.catalog != null)
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                for (final kind in [
                  'Videos',
                  'Channels',
                  'Playlists',
                  'Following',
                  'Liked videos',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(kind),
                      selected: _videoKind == kind,
                      onSelected: (_) => _selectVideoKind(kind),
                    ),
                  ),
              ],
            ),
          ),
        if (widget.video &&
            !focused &&
            !{'Following', 'Liked videos'}.contains(_videoKind))
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (c, i) {
                const topics = [
                  'All',
                  'Music',
                  'Gaming',
                  'Technology',
                  'Podcasts',
                ];
                return ChoiceChip(
                  label: Text(topics[i]),
                  selected: _discovering && _topic == topics[i],
                  onSelected: (_) {
                    _focus.unfocus();
                    _text.clear();
                    _discover(topics[i]);
                  },
                );
              },
            ),
          ),
        Expanded(
          child: focused
              ? Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      Expanded(
                        child: _suggestionLoading
                            ? ListView(children: const [SuggestionSkeleton()])
                            : suggestions.isEmpty
                            ? Center(
                                child: Text(
                                  _text.text.isEmpty
                                      ? 'Search for something you love'
                                      : 'Search for “${_text.text}”',
                                ),
                              )
                            : ListView.builder(
                                itemCount: suggestions.length,
                                itemBuilder: (c, i) => ListTile(
                                  leading: Icon(
                                    _text.text.isEmpty
                                        ? Icons.history
                                        : Icons.search,
                                  ),
                                  title: Text(
                                    suggestions[i],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _submit(suggestions[i]),
                                  trailing: IconButton(
                                    tooltip: 'Use suggestion',
                                    icon: const Icon(Icons.north_west),
                                    onPressed: () {
                                      _text.text = suggestions[i];
                                      _text.selection = TextSelection.collapsed(
                                        offset: _text.text.length,
                                      );
                                      _suggest(_text.text);
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                )
              : widget.video && widget.catalog != null && _videoKind != 'Videos'
              ? _catalogList()
              : _results.query.isEmpty
              ? _empty(context)
              : ListView.builder(
                  itemCount: queue.length + 2 + (showCollections ? 1 : 0),
                  findChildIndexCallback: (key) =>
                      showCollections && key == collectionKey
                      ? collectionIndex
                      : null,
                  itemBuilder: (context, rawIndex) {
                    if (showCollections && rawIndex == collectionIndex) {
                      return MusicSearchCollections(
                        key: collectionKey,
                        query: _results.query,
                        catalog: _musicCatalog,
                        library: widget.library,
                        onOpen: widget.onMusicCollection!,
                      );
                    }
                    final index = showCollections && rawIndex > collectionIndex
                        ? rawIndex - 1
                        : rawIndex;
                    if (index > 0 && index <= queue.length) {
                      return widget.row(queue[index - 1], queue);
                    }
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                            child: Text(
                              widget.video
                                  ? (_discovering
                                        ? 'Explore videos'
                                        : 'Search results')
                                  : 'Songs',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (widget.video &&
                              _discovering &&
                              widget.library.followedChannels.isNotEmpty)
                            _followingStrip(),
                          if (widget.video &&
                              _discovering &&
                              _followLoading &&
                              _followVideos.isEmpty)
                            const ContentSkeleton(
                              video: true,
                              count: 1,
                              label: 'Loading followed-channel recommendations',
                            ),
                          if (widget.video &&
                              _discovering &&
                              _followError != null)
                            CatalogMessage(
                              message: _followError!,
                              onRetry: _loadFollowed,
                            ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_results.loading)
                          ContentSkeleton(
                            video: widget.video,
                            count: _results.tracks.isEmpty
                                ? (widget.video ? 2 : 6)
                                : 1,
                          ),
                        if (_results.error != null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  'Couldn’t load results. Check your connection and try again.',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton.icon(
                                  onPressed: () => _results.submit(
                                    _results.query,
                                    more: _results.tracks.isNotEmpty,
                                  ),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        if (!_results.loading &&
                            _results.error == null &&
                            _results.tracks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No results found. Try another search.',
                            ),
                          ),
                        if (!_results.loading && _results.nextPage != null)
                          TextButton(
                            onPressed: () =>
                                _results.submit(_results.query, more: true),
                            child: const Text('Load more'),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _followingStrip() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text('Following'),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.library.followedChannels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final channel = widget.library.followedChannels[index];
              return SizedBox(
                width: 80,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => widget.onChannel?.call(channel),
                  child: Column(
                    children: [
                      ChannelAvatar(channel: channel, size: 56),
                      const SizedBox(height: 6),
                      Text(
                        channel.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
  Widget _catalogList() {
    if (_videoKind == 'Liked videos') {
      final query = _text.text.trim().toLowerCase();
      final videos = widget.library.likedVideos
          .where((t) => '${t.title} ${t.artist}'.toLowerCase().contains(query))
          .toList();
      return ListView.builder(
        key: const PageStorageKey('liked-videos'),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: videos.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Text(
                videos.isEmpty
                    ? (query.isEmpty
                          ? 'Videos you like will appear here.'
                          : 'No matching liked videos.')
                    : 'Liked videos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return widget.row(videos[index - 1], videos);
        },
      );
    }

    final following = _videoKind == 'Following';
    final channels = following
        ? widget.library.followedChannels
              .where(
                (c) => c.name.toLowerCase().contains(
                  _text.text.trim().toLowerCase(),
                ),
              )
              .toList()
        : _channels;
    final channelMode = following || _videoKind == 'Channels';
    final count = channelMode ? channels.length : _playlists.length;
    return ListView.builder(
      key: ValueKey('video-catalog-$_videoKind'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: count + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Text(
              following ? 'Following in Undertune' : _videoKind,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        if (index <= count) {
          return channelMode
              ? VideoChannelRow(
                  channel: channels[index - 1],
                  following: widget.library.isFollowing(channels[index - 1]),
                  onTap: () => widget.onChannel?.call(channels[index - 1]),
                )
              : VideoPlaylistRow(
                  playlist: _playlists[index - 1],
                  saved: widget.library.hasVideoPlaylist(_playlists[index - 1]),
                  onTap: () =>
                      widget.onVideoPlaylist?.call(_playlists[index - 1]),
                );
        }
        if (!following && _catalogLoading) {
          return CatalogSkeleton(channels: channelMode);
        }
        if (!following && _catalogError != null) {
          return CatalogMessage(
            message: _catalogError!,
            onRetry: () =>
                _loadCatalog(_catalogQuery, more: _catalogNext != null),
          );
        }
        if (count == 0) {
          return CatalogMessage(
            message: following
                ? 'Follow a channel to find it here and personalize your video suggestions.'
                : 'No ${_videoKind.toLowerCase()} found. Try another search.',
          );
        }
        if (!following && _catalogNext != null) {
          return TextButton(
            onPressed: () => _loadCatalog(_catalogQuery, more: true),
            child: const Text('Load more'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _empty(BuildContext context) => ListView(
    key: const PageStorageKey('search-discovery'),
    padding: const EdgeInsets.only(bottom: 28),
    children: [
      if (widget.library.searches.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
          child: Text(
            'Recent searches',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        ...widget.library.searches
            .take(4)
            .map(
              (s) => ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                minLeadingWidth: 20,
                leading: const Icon(Icons.history, size: 18),
                title: Text(
                  s,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => _submit(s),
              ),
            ),
      ],
      if (!widget.video)
        Discovery(
          library: widget.library,
          extractor: widget.extractor,
          row: widget.suggestionRow ?? widget.row,
          active: widget.active && !_focus.hasFocus,
        )
      else
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Find your next watch.'),
        ),
    ],
  );
}
