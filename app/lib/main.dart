import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'media/media_session.dart';
import 'library.dart';
import 'media/extractor.dart';
import 'media/playback.dart';
import 'media/downloads.dart';
import 'media/playlist_downloads.dart';
import 'media/music_collections.dart';
import 'screens/music_collection.dart';
import 'screens/downloads.dart';
import 'screens/about.dart';
import 'screens/search.dart';
import 'screens/player.dart';
import 'screens/video.dart';
import 'screens/video_channel.dart';
import 'screens/video_playlist.dart';
import 'media/video_catalog.dart';
import 'screens/live.dart';
import 'screens/onboarding.dart';
import 'theme.dart';
import 'widgets/track_row.dart';
import 'screens/home.dart';
import 'screens/library.dart';
import 'screens/playlist.dart';
import 'widgets/corner_video_frame.dart';
import 'widgets/app_navigation.dart';
import 'widgets/audio_mini_player.dart';
import 'widgets/branding.dart';
import 'widgets/video_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  final background = await AudioService.init(
    builder: UndertuneMediaSession.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kafeyn.undertune.playback',
      androidNotificationChannelName: 'Undertune playback',
      androidNotificationOngoing: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );
  final library = await Library.load();
  runApp(UndertuneApp(library: library, background: background));
}

class UndertuneApp extends StatefulWidget {
  const UndertuneApp({super.key, required this.library, this.background});
  final Library library;
  final UndertuneMediaSession? background;
  @override
  State<UndertuneApp> createState() => _UndertuneAppState();
}

class _UndertuneAppState extends State<UndertuneApp> {
  final _extractor = Extractor();
  final Downloads _downloads = Downloads();
  late final Playback _playback = Playback(
    _extractor,
    widget.library,
    localFor: _downloads.localFor,
  );
  @override
  void initState() {
    super.initState();
    widget.background?.bindMusic(_playback);
    unawaited(_downloads.refresh());
    unawaited(widget.library.checkLegacyLive(_extractor));
  }

  @override
  void dispose() {
    widget.background?.unbindMusic();
    _playback.dispose();
    _downloads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.library,
    builder: (context, _) {
      final atmosphere = Atmosphere.byId(widget.library.themeId);
      return MaterialApp(
        title: 'Undertune',
        debugShowCheckedModeBanner: false,
        theme: atmosphere.data,
        themeAnimationDuration: const Duration(milliseconds: 350),
        home:
            !widget.library.onboardingComplete &&
                widget.library.storageError == null
            ? OnboardingScreen(library: widget.library)
            : UndertuneShell(
                library: widget.library,
                extractor: _extractor,
                playback: _playback,
                downloads: _downloads,
                background: widget.background,
              ),
        builder: (context, child) => ThemeSystemBars(
          child: AtmosphericBackground(theme: atmosphere, child: child!),
        ),
      );
    },
  );
}

class UndertuneShell extends StatefulWidget {
  const UndertuneShell({
    super.key,
    required this.library,
    required this.extractor,
    required this.playback,
    required this.downloads,
    this.background,
  });
  final Library library;
  final Extractor extractor;
  final Playback playback;
  final Downloads downloads;
  final UndertuneMediaSession? background;
  @override
  State<UndertuneShell> createState() => _UndertuneShellState();
}

class _UndertuneShellState extends State<UndertuneShell>
    with SingleTickerProviderStateMixin {
  late final PlaylistDownloads _playlistDownloads;
  @override
  void initState() {
    super.initState();
    _playlistDownloads = PlaylistDownloads(
      widget.library,
      widget.downloads,
      widget.extractor,
    );
  }

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    value: 1,
  );
  @override
  void dispose() {
    _playlistDownloads.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _animate() {
    if (!MediaQuery.disableAnimationsOf(context)) _entrance.forward(from: 0);
  }

  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0, _searchFocus = 0;
  String? _collection;
  final _videoCatalog = VideoCatalog();
  final _musicCatalog = MusicCatalog();
  MusicCollection? _musicCollection;
  VideoChannel? _channelPage;
  RemoteVideoPlaylist? _remotePlaylist;
  bool get _videoDetail => _channelPage != null || _remotePlaylist != null;
  Track? _videoTrack;
  bool _videoMinimized = false, _playerOpen = false;
  int _videoRequest = 0;
  bool _videoSearch = false, _history = false, _live = false;
  Library get library => widget.library;
  Playback get playback => widget.playback;
  void _home() {
    _animate();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = 0;
      _collection = null;
      _channelPage = null;
      _remotePlaylist = null;
      _musicCollection = null;
      _videoSearch = false;
      _history = false;
      _live = false;
    });
  }

  void _select(int value) {
    _animate();
    final reselect = value == 1 && _tab == 1 && !_videoSearch;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = value;
      _collection = null;
      _channelPage = null;
      _remotePlaylist = null;
      _musicCollection = null;
      _videoSearch = false;
      _history = false;
      _live = false;
      if (reselect) _searchFocus++;
    });
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _message(e.toString());
    }
  }

  Future<void> _create({Track? track}) async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => PlaylistEditor(library: library),
    );
    if (id == null) return;
    await _guard(() async {
      if (track != null) await library.addToPlaylist(id, track);
      if (mounted) {
        final name = library.playlists.firstWhere((p) => p.id == id).name;
        _message(track == null ? 'Playlist created' : 'Added to $name');
      }
    });
  }

  Future<void> _add(Track track) async {
    if (track.live) {
      await _liveAction(track);
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Add to playlist',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create playlist'),
              onTap: () => Navigator.pop(c, 'new'),
            ),
            ...library.playlists.map(
              (p) => ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(p.name),
                subtitle: Text('${p.tracks.length} tracks'),
                trailing: p.tracks.any((e) => e.key == track.key)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(c, p.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (id == 'new') {
      await _create(track: track);
    } else if (id != null) {
      await _guard(() async {
        await library.addToPlaylist(id, track);
        if (mounted) _message('Saved to playlist');
      });
    }
  }

  Future<void> _actions(Track track) async {
    if (track.live) {
      final saved = library.liveStreams.any((t) => t.key == track.key);
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ListTile(
                leading: Icon(saved ? Icons.remove_circle_outline : Icons.add),
                title: Text(saved ? 'Remove from Live' : 'Add to Live'),
                onTap: () => Navigator.pop(c, 'live'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                onTap: () => Navigator.pop(c, 'copy'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (action == 'live') await _liveAction(track);
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: track.url));
        if (mounted) _message('Link copied');
      }
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Artwork(track.artwork),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(track.artist, maxLines: 1),
              ),
              if (track.video)
                ListTile(
                  leading: Icon(
                    library.isLiked(track)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                  title: Text(
                    library.isLiked(track)
                        ? 'Remove from liked videos'
                        : 'Like video',
                  ),
                  onTap: () => Navigator.pop(c, 'likeVideo'),
                ),
              ListTile(
                leading: Icon(
                  library.isSaved(track)
                      ? Icons.library_add_check
                      : Icons.library_add_outlined,
                ),
                title: Text(
                  library.isSaved(track) ? 'Added to Tracks' : 'Add to Tracks',
                ),
                onTap: library.isSaved(track)
                    ? null
                    : () => Navigator.pop(c, 'save'),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Add to playlist'),
                onTap: () => Navigator.pop(c, 'add'),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text('Download ${library.downloadType}'),
                onTap: () => Navigator.pop(c, 'download'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                onTap: () => Navigator.pop(c, 'copy'),
              ),
              if (!track.video)
                ListTile(
                  leading: const Icon(Icons.ondemand_video),
                  title: const Text('Watch video'),
                  onTap: () => Navigator.pop(c, 'video'),
                ),
              if (_collection != null &&
                  _collection != 'liked' &&
                  _collection != 'tracks')
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline),
                  title: const Text('Remove from playlist'),
                  onTap: () => Navigator.pop(c, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'likeVideo') {
      await _guard(() => library.toggleLike(track.asVideo(true)));
    }
    if (action == 'save') await _guard(() => library.saveTrack(track));
    if (action == 'add') await _add(track);
    if (action == 'download') await _download(track);
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: track.url));
      _message('Link copied');
    }
    if (action == 'video') {
      await _play(track.asVideo(true), [track.asVideo(true)]);
    }
    if (action == 'remove') {
      await _guard(() => library.removeFromPlaylist(_collection!, track));
    }
  }

  Future<void> _download(Track track) async {
    // A SnackBarAction dismisses its own bar after calling us. Start after that
    // synchronous dismissal so a retry cannot close the new preparation status.
    await Future<void>.value();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    final preparation = messenger.showSnackBar(
      SnackBar(
        // Completion, failure, or dismissal ends this contextual status.
        duration: const Duration(days: 1),
        content: Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Preparing download…')),
          ],
        ),
      ),
    );
    var statusOpen = true;
    unawaited(preparation.closed.then((_) => statusOpen = false));
    try {
      await widget.downloads.enqueue(
        track,
        widget.extractor,
        preferences: library,
      );
    } catch (_) {
      if (mounted) {
        if (statusOpen) preparation.close();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Download couldn’t start.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_download(track)),
            ),
          ),
        );
      }
      return;
    }
    if (mounted) {
      if (statusOpen) preparation.close();
      _message('Download started');
    }
  }

  Future<void> _play(
    Track track,
    List<Track> queue, {
    String? playlistId,
  }) async {
    if (track.video || track.live) {
      await playback.stop();
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (_playerOpen) Navigator.pop(context);
      setState(() {
        _videoTrack = track.asVideo(true);
        _videoMinimized = false;
        _videoRequest++;
      });
      return;
    }
    if (_videoTrack != null) {
      setState(() {
        _videoTrack = null;
        _videoMinimized = false;
      });
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    unawaited(playback.play(track, from: queue, playlistId: playlistId));
    _openPlayer();
  }

  Future<void> _openPlayer() async {
    if (_playerOpen) return;
    setState(() => _playerOpen = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            playback: playback,
            library: library,
            onAdd: _add,
            onActions: _actions,
            onPlay: (t) => _play(t, [t]),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _playerOpen = false);
    }
  }

  Widget _row(Track track, List<Track> tracks) => track.video || track.live
      ? VideoCard(
          track: track,
          onTap: () => _play(track, tracks),
          onMore: () => _actions(track),
          onChannel: track.channelUrl.isEmpty
              ? null
              : () => _openVideoChannel(
                  VideoChannel(
                    id: track.channelUrl,
                    url: track.channelUrl,
                    name: track.artist,
                    artwork: track.channelArtwork,
                    serviceId: track.serviceId,
                  ),
                ),
        )
      : TrackRow(
          track: track,
          downloaded: widget.downloads.localFor(track) != null,
          liked: library.isLiked(track),
          active: playback.current?.key == track.key,
          onTap: () => _play(track, tracks),
          onLike: () => _guard(() => library.toggleLike(track)),
          onMore: () => _actions(track),
        );
  void _openCollection(String id) {
    _animate();
    setState(() {
      _tab = 2;
      _collection = id;
      _channelPage = null;
      _remotePlaylist = null;
      _musicCollection = null;
      _live = false;
    });
  }

  void _openVideos() {
    _animate();
    setState(() {
      _videoSearch = true;
      _tab = 1;
      _history = false;
      _collection = null;
      _channelPage = null;
      _remotePlaylist = null;
      _musicCollection = null;
      _live = false;
    });
  }

  void _openMusicCollection(MusicCollection source) {
    FocusManager.instance.primaryFocus?.unfocus();
    _animate();
    setState(() {
      _musicCollection = source;
      _channelPage = null;
      _remotePlaylist = null;
    });
  }

  void _openVideoChannel(VideoChannel channel) {
    FocusManager.instance.primaryFocus?.unfocus();
    _animate();
    setState(() {
      _channelPage = channel;
      _remotePlaylist = null;
      _musicCollection = null;
    });
  }

  void _openVideoPlaylist(RemoteVideoPlaylist playlist) {
    FocusManager.instance.primaryFocus?.unfocus();
    _animate();
    setState(() => _remotePlaylist = playlist);
  }

  void _back() {
    if (_musicCollection != null) {
      _animate();
      setState(() => _musicCollection = null);
    } else if (_remotePlaylist != null) {
      _animate();
      setState(() => _remotePlaylist = null);
    } else if (_channelPage != null) {
      _animate();
      setState(() => _channelPage = null);
    } else {
      _home();
    }
  }

  Future<void> _liveAction(Track track) => _guard(() async {
    if (library.liveStreams.any((t) => t.key == track.key)) {
      await library.removeLive(track);
      if (mounted) _message('Removed from Live');
    } else {
      final info = await widget.extractor.resolve(track.asVideo(true));
      if (info['live'] != true) {
        throw StateError('This broadcast is no longer live.');
      }
      await library.addLive(track);
      if (mounted) _message('Added to Live');
    }
  });

  Widget _musicRow(
    Track track,
    List<Track> queue,
    double size, {
    bool compact = false,
  }) => TrackRow(
    track: track,
    artworkSize: size,
    verticalPadding: compact
        ? 4
        : size == 64
        ? 5
        : null,
    horizontalPadding: compact ? 20 : 24,
    artworkGap: compact ? 10 : 12,
    titleLines: 2,
    showDuration: true,
    downloaded: widget.downloads.localFor(track) != null,
    liked: library.isLiked(track),
    active: playback.current?.key == track.key,
    onTap: () => _play(track, queue),
    onLike: () => _guard(() => library.toggleLike(track)),
    onMore: () => _actions(track),
  );
  Widget _homePage() => HomeScreen(
    library: library,
    extractor: widget.extractor,
    onCollection: _openCollection,
    onVideos: _openVideos,
    onSearch: () => _select(1),
    active:
        _tab == 0 &&
        _collection == null &&
        !_history &&
        !_videoSearch &&
        (_videoTrack == null || _videoMinimized),
    onPlay: _play,
    suggestionRow: (t, q) => _musicRow(t, q, 64, compact: true),
  );
  Widget _libraryPage() => LibraryScreen(
    library: library,
    onCollection: _openCollection,
    onVideos: _openVideos,
    onDownloads: _openDownloads,
    onVideoPlaylist: _openVideoPlaylist,
    trackRow: (t, q) => _musicRow(t, q, 72 * .8, compact: true),
  );
  Widget _playlistPage() => PlaylistScreen(
    playlistDownloads: _playlistDownloads,
    key: ValueKey(_collection),
    id: _collection!,
    library: library,
    extractor: widget.extractor,
    playback: playback,
    downloads: widget.downloads,
    onPlay: (track, queue) => _play(track, queue, playlistId: _collection),
    onActions: _actions,
    onDeleted: _home,
  );

  void _openDownloads() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => DownloadsScreen(
        downloads: widget.downloads,
        library: library,
        onPlay: (entry) {
          Navigator.pop(context);
          final track = entry.track.asVideo(entry.kind == 'video');
          _play(track, [track]);
        },
      ),
    ),
  );
  void _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: library,
          builder: (c, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Settings',
                  style: feelfreeHeadingStyle.copyWith(fontSize: 36),
                ),
              ),
              SwitchListTile(
                title: const Text('SponsorBlock for videos'),
                subtitle: const Text(
                  'Skip sponsor segments using community reports.',
                ),
                value: library.sponsorBlock,
                onChanged: (value) =>
                    _guard(() => library.setSponsorBlock(value)),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text(Atmosphere.byId(library.themeId).name),
                onTap: () {
                  Navigator.pop(c);
                  _themes();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
  void _themes() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Choose your atmosphere',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${Atmosphere.all.length} moods. One Undertune.'),
            ),
            ...Atmosphere.all.map(
              (t) => ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: [t.canvas, ...t.clouds]),
                  ),
                ),
                title: Text(t.name),
                trailing: library.themeId == t.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  await _guard(() => library.setTheme(t.id));
                  if (c.mounted && ModalRoute.of(c)?.isCurrent == true) {
                    Navigator.pop(c);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([library, playback, widget.downloads]),
    builder: (context, _) {
      final secondary =
          _collection != null ||
          _history ||
          _videoSearch ||
          _live ||
          _videoDetail ||
          _musicCollection != null;
      return PlaylistThemeScope(
        themeId: library.playlists
            .where((p) => p.id == _collection)
            .firstOrNull
            ?.themeId,
        child: PopScope(
          canPop:
              !secondary &&
              _tab == 0 &&
              (_videoTrack == null || _videoMinimized),
          onPopInvokedWithResult: (p, _) {
            if (!p) {
              if (_videoTrack != null && !_videoMinimized) {
                setState(() => _videoMinimized = true);
              } else {
                _back();
              }
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: _videoTrack != null && !_videoMinimized,
                child: TickerMode(
                  enabled: _videoTrack == null || _videoMinimized,
                  child: Scaffold(
                    key: _scaffold,
                    appBar: UndertuneAppBar(
                      back: secondary,
                      backLabel: _videoDetail || _musicCollection != null
                          ? 'Back'
                          : 'Home',
                      onMenu: secondary
                          ? _back
                          : () => _scaffold.currentState!.openDrawer(),
                      onAdd: _create,
                      title: _musicCollection != null
                          ? (_musicCollection!.kind == 'album'
                                ? 'Album'
                                : 'Music playlist')
                          : _remotePlaylist != null
                          ? 'Video playlist'
                          : _channelPage != null
                          ? 'Channel'
                          : _history
                          ? 'History'
                          : _live
                          ? 'Live'
                          : _videoSearch
                          ? 'Videos'
                          : _collection != null
                          ? 'Your collection'
                          : _tab == 1
                          ? 'Search'
                          : null,
                    ),
                    drawer: Drawer(
                      child: SafeArea(
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: BrandWordmark(width: 190),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.home_outlined),
                              title: const Text('Home'),
                              onTap: () {
                                Navigator.pop(context);
                                _home();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.ondemand_video),
                              title: const Text('Videos'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _videoSearch = true;
                                  _live = false;
                                  _tab = 1;
                                  _history = false;
                                  _collection = null;
                                  _channelPage = null;
                                  _remotePlaylist = null;
                                  _musicCollection = null;
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.sensors),
                              title: const Text('Live'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _live = true;
                                  _videoSearch = false;
                                  _history = false;
                                  _collection = null;
                                  _channelPage = null;
                                  _remotePlaylist = null;
                                  _musicCollection = null;
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.download_outlined),
                              title: const Text('Downloads'),
                              onTap: () {
                                Navigator.pop(context);
                                _openDownloads();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.history),
                              title: const Text('History'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _history = true;
                                  _live = false;
                                  _collection = null;
                                  _channelPage = null;
                                  _remotePlaylist = null;
                                  _musicCollection = null;
                                  _videoSearch = false;
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.palette_outlined),
                              title: const Text('Themes'),
                              onTap: () {
                                Navigator.pop(context);
                                _themes();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.settings_outlined),
                              title: const Text('Settings'),
                              onTap: () {
                                Navigator.pop(context);
                                _settings();
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: const Text('About Undertune'),
                              onTap: () {
                                Navigator.pop(context);
                                showAboutUndertune(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    body: library.storageError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(library.storageError!),
                            ),
                          )
                        : FadeTransition(
                            opacity: CurvedAnimation(
                              parent: _entrance,
                              curve: Curves.easeOut,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Offstage(
                                  offstage: secondary,
                                  child: TickerMode(
                                    enabled: !secondary,
                                    child: IndexedStack(
                                      index: _tab,
                                      children: [
                                        TickerMode(
                                          enabled: _tab == 0,
                                          child: _homePage(),
                                        ),
                                        TickerMode(
                                          enabled: _tab == 1,
                                          child: SearchScreen(
                                            key: const ValueKey('music'),
                                            musicCatalog: _musicCatalog,
                                            onMusicCollection:
                                                _openMusicCollection,
                                            library: library,
                                            extractor: widget.extractor,
                                            row: _row,
                                            suggestionRow: (t, q) => _musicRow(
                                              t,
                                              q,
                                              64,
                                              compact: true,
                                            ),
                                            focusRequest: _searchFocus,
                                            active:
                                                _tab == 1 &&
                                                !secondary &&
                                                (_videoTrack == null ||
                                                    _videoMinimized),
                                          ),
                                        ),
                                        TickerMode(
                                          enabled: _tab == 2,
                                          child: _libraryPage(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Offstage(
                                  offstage: !_videoSearch || _videoDetail,
                                  child: TickerMode(
                                    enabled: _videoSearch && !_videoDetail,
                                    child: SearchScreen(
                                      key: const ValueKey('videos'),
                                      library: library,
                                      extractor: widget.extractor,
                                      video: true,
                                      active:
                                          _videoSearch &&
                                          !_videoDetail &&
                                          (_videoTrack == null ||
                                              _videoMinimized),
                                      catalog: _videoCatalog,
                                      onChannel: _openVideoChannel,
                                      onVideoPlaylist: _openVideoPlaylist,
                                      row: _row,
                                    ),
                                  ),
                                ),
                                if (_collection != null)
                                  Offstage(
                                    offstage: _videoDetail,
                                    child: _playlistPage(),
                                  ),
                                if (_live)
                                  LiveScreen(
                                    library: library,
                                    extractor: widget.extractor,
                                    onPlay: (t) => _play(t, [t]),
                                    onActions: _actions,
                                    onAdd: _openVideos,
                                  ),
                                if (_history && !_videoDetail)
                                  ListView(
                                    children: [
                                      if (library.history.isEmpty)
                                        const ListTile(
                                          title: Text(
                                            'No listening history yet.',
                                          ),
                                        ),
                                      ...library.history.map(
                                        (t) => _row(t, library.history),
                                      ),
                                    ],
                                  ),
                                if (_musicCollection != null)
                                  MusicCollectionScreen(
                                    key: ValueKey(_musicCollection!.key),
                                    collection: _musicCollection!,
                                    catalog: _musicCatalog,
                                    library: library,
                                    row: (t, q) =>
                                        _musicRow(t, q, 64, compact: true),
                                    onSaved: (id) {
                                      setState(() => _musicCollection = null);
                                      _openCollection(id);
                                    },
                                  ),
                                if (_channelPage != null)
                                  Offstage(
                                    offstage: _remotePlaylist != null,
                                    child: TickerMode(
                                      enabled: _remotePlaylist == null,
                                      child: VideoChannelScreen(
                                        key: ValueKey(_channelPage!.key),
                                        channel: _channelPage!,
                                        library: library,
                                        catalog: _videoCatalog,
                                        row: _row,
                                        onPlaylist: _openVideoPlaylist,
                                      ),
                                    ),
                                  ),
                                if (_remotePlaylist != null)
                                  VideoPlaylistScreen(
                                    key: ValueKey(_remotePlaylist!.key),
                                    playlist: _remotePlaylist!,
                                    library: library,
                                    catalog: _videoCatalog,
                                    row: _row,
                                    onPlay: (t) => _play(t.asVideo(true), [
                                      t.asVideo(true),
                                    ]),
                                  ),
                              ],
                            ),
                          ),
                    bottomNavigationBar: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (playback.current != null)
                          Dismissible(
                            key: const ValueKey('mini-player'),
                            direction: DismissDirection.down,
                            onDismissed: (_) => playback.stop(),
                            child: AudioMiniPlayer(
                              playback: playback,
                              extractor: widget.extractor,
                              onOpen: _openPlayer,
                              visible: !_playerOpen,
                            ),
                          ),
                        UndertuneNavigation(
                          selectedIndex: _tab,
                          onSelected: _select,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_videoTrack != null)
                CornerVideoFrame(
                  minimized: _videoMinimized,
                  child: VideoScreen(
                    key: const ValueKey('active-video'),
                    background: widget.background,
                    track: _videoTrack!,
                    extractor: widget.extractor,
                    library: library,
                    sponsorBlock: library.sponsorBlock,
                    localFor: widget.downloads.videoFor,
                    onSave: _add,
                    onChannel: (channel) {
                      setState(() => _videoMinimized = true);
                      _openVideoChannel(channel);
                    },
                    onActions: _actions,
                    minimized: _videoMinimized,
                    loadRequest: _videoRequest,
                    onMinimize: () => setState(() => _videoMinimized = true),
                    onExpand: () => setState(() => _videoMinimized = false),
                    onClose: () => setState(() {
                      _videoTrack = null;
                      _videoMinimized = false;
                    }),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
