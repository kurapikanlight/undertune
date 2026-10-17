Map<String, dynamic>? selectAudio(
  List<dynamic> streams, {
  int maxBitrate = 0,
  bool mp4Only = false,
}) {
  final sources = streams
      .map((s) => Map<String, dynamic>.from(s as Map))
      .where(
        (s) =>
            (s['url'] as String? ?? '').isNotEmpty &&
            (!mp4Only || s['extension'] == 'm4a' || s['mime'] == 'audio/mp4'),
      )
      .toList();
  int bitrate(Map s) => (s['bitrate'] as num?)?.toInt() ?? 0;
  sources.sort((a, b) => bitrate(b).compareTo(bitrate(a)));
  if (sources.isEmpty) return null;
  if (maxBitrate <= 0) return sources.first;
  return sources
          .where((s) => bitrate(s) > 0 && bitrate(s) <= maxBitrate)
          .firstOrNull ??
      sources.last;
}

Map<String, dynamic>? selectDownloadVideo(
  Map<String, dynamic> info, {
  int maxHeight = 0,
}) {
  final sources =
      <Map<String, dynamic>>[
            for (final s in info['video'] as List? ?? [])
              {...Map<String, dynamic>.from(s as Map), 'videoOnly': false},
            for (final s in info['videoOnly'] as List? ?? [])
              {...Map<String, dynamic>.from(s as Map), 'videoOnly': true},
          ]
          .where(
            (s) =>
                (s['url'] as String? ?? '').isNotEmpty &&
                (s['extension'] == 'mp4' || s['mime'] == 'video/mp4') &&
                ((s['codec'] as String? ?? '').isEmpty ||
                    (s['codec'] as String).toLowerCase().contains('avc')),
          )
          .toList();
  int height(Map s) =>
      int.tryParse(
        RegExp(r'^\d+').stringMatch(s['quality'] as String? ?? '') ?? '',
      ) ??
      0;
  sources.sort((a, b) {
    final order = height(b).compareTo(height(a));
    return order != 0
        ? order
        : (a['videoOnly'] == true ? 1 : 0).compareTo(
            b['videoOnly'] == true ? 1 : 0,
          );
  });
  if (sources.isEmpty) return null;
  if (maxHeight <= 0) return sources.first;
  return sources
          .where((s) => height(s) > 0 && height(s) <= maxHeight)
          .firstOrNull ??
      sources.last;
}
