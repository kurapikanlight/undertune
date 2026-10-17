import 'package:flutter/material.dart';
import '../media/playlist_downloads.dart';

class PlaylistDownloadControls extends StatelessWidget {
  const PlaylistDownloadControls({
    super.key,
    required this.id,
    required this.downloads,
  });
  final String id;
  final PlaylistDownloads downloads;
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Couldn’t update playlist downloads.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _run(context, action),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: downloads,
    builder: (context, _) {
      final automatic = downloads.library.autoDownloadPlaylists.contains(id);
      final preparing = downloads.preparing(id);
      final failed = downloads.failedCount(id) > 0;
      final label = failed
          ? 'Retry playlist downloads'
          : automatic
          ? 'Turn off playlist downloads'
          : 'Download all';
      return Semantics(
        toggled: automatic,
        child: IconButton(
          tooltip: label,
          onPressed: downloads.changing(id)
              ? null
              : () => _run(
                  context,
                  () => automatic && !failed
                      ? downloads.setAutomatic(id, false)
                      : downloads.downloadAll(id),
                ),
          color: automatic ? Theme.of(context).colorScheme.primary : null,
          icon: preparing
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                    semanticsLabel: 'Preparing playlist downloads',
                  ),
                )
              : Icon(
                  failed
                      ? Icons.error_outline_rounded
                      : automatic
                      ? Icons.download_done_rounded
                      : Icons.download_outlined,
                  semanticLabel: label,
                ),
        ),
      );
    },
  );
}
