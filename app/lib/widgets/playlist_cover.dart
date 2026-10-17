import 'dart:io';
import 'package:flutter/material.dart';
import '../media/extractor.dart';
import 'track_row.dart';
import 'media_image.dart';

class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.tracks,
    this.coverPath,
    this.sourceArtwork,
    this.liked = false,
    this.size = 96,
  });
  final List<Track> tracks;
  final String? coverPath, sourceArtwork;
  final bool liked;
  final double size;

  Widget _tile(BuildContext context, String url) => url.isEmpty
      ? const ColoredBox(color: Colors.black)
      : MediaImage.network(
          url,
          cacheWidth: artworkDecodeWidth(
            context,
            tracks.length >= 4 ? size / 2 : size,
          ),
          fallback: const ColoredBox(color: Colors.black),
        );

  Widget _automatic(BuildContext context) {
    if (tracks.isEmpty) return const ColoredBox(color: Colors.black);
    if (tracks.length == 1) return _tile(context, tracks.first.artwork);
    if (tracks.length < 4) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in tracks.take(2))
            Expanded(child: _tile(context, t.artwork)),
        ],
      );
    }
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 2; col++)
                  Expanded(
                    child: _tile(context, tracks[row * 2 + col].artwork),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (liked) return Artwork('', size: size, liked: true);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size > 120 ? 18 : 10),
      child: SizedBox.square(
        dimension: size,
        child: coverPath == null
            ? sourceArtwork != null && sourceArtwork!.isNotEmpty
                  ? MediaImage.network(
                      sourceArtwork!,
                      cacheWidth: artworkDecodeWidth(context, size),
                      fallback: _automatic(context),
                    )
                  : _automatic(context)
            : MediaImage(
                image: ResizeImage.resizeIfNeeded(
                  artworkDecodeWidth(context, size),
                  null,
                  FileImage(File(coverPath!)),
                ),
                fallback: _automatic(context),
              ),
      ),
    );
  }
}
