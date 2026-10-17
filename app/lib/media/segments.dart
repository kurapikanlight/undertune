import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class SegmentSkipper {
  SegmentSkipper(List<dynamic> data) {
    for (final item in data) {
      if (item is! Map || item['category'] != 'sponsor') continue;
      final segment = item['segment'];
      if (segment is! List ||
          segment.length != 2 ||
          segment[0] is! num ||
          segment[1] is! num) {
        continue;
      }
      final start = (segment[0] as num).toDouble(),
          end = (segment[1] as num).toDouble();
      if (!start.isFinite || !end.isFinite || start < 0 || end <= start) {
        continue;
      }
      _segments.add((start: (start * 1000).round(), end: (end * 1000).round()));
    }
  }
  final List<({int start, int end})> _segments = [];
  final Set<int> _skipped = {};
  Duration? target(Duration position) {
    for (var i = 0; i < _segments.length; i++) {
      final segment = _segments[i];
      if (!_skipped.contains(i) &&
          position.inMilliseconds >= segment.start &&
          position.inMilliseconds < segment.end) {
        _skipped.add(i);
        return Duration(milliseconds: segment.end);
      }
    }
    return null;
  }

  static Future<SegmentSkipper> load(String url) async {
    final uri = Uri.parse(url);
    final id = uri.host == 'youtu.be'
        ? uri.pathSegments.firstOrNull
        : uri.queryParameters['v'];
    if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      return SegmentSkipper([]);
    }
    final hash = sha256.convert(utf8.encode(id)).toString().substring(0, 4);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        Uri.https('sponsor.ajay.app', '/api/skipSegments/$hash', {
          'categories': '["sponsor"]',
          'actionTypes': '["skip"]',
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) return SegmentSkipper([]);
      final data =
          jsonDecode(
                await response
                    .transform(utf8.decoder)
                    .join()
                    .timeout(const Duration(seconds: 15)),
              )
              as List;
      final result = data
          .whereType<Map>()
          .where((e) => e['videoID'] == id)
          .firstOrNull;
      return SegmentSkipper(result?['segments'] as List? ?? []);
    } finally {
      client.close(force: true);
    }
  }
}
