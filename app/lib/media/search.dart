import 'package:flutter/foundation.dart';
import 'extractor.dart';

class SearchResults extends ChangeNotifier {
  SearchResults(this.extractor);
  final Extractor extractor;
  List<Track> tracks = [];
  String query = '';
  String? nextPage, error;
  bool loading = false;
  int _generation = 0;
  bool _disposed = false;
  Future<void> submit(String text, {bool more = false}) async {
    if (more && (loading || nextPage == null)) return;
    final generation = ++_generation;
    if (!more) {
      query = text.trim();
      tracks = [];
      nextPage = null;
    }
    if (query.isEmpty) {
      loading = false;
      error = null;
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await extractor.search(
        query,
        page: more ? nextPage : null,
      );
      if (_disposed || generation != _generation) return;
      final keys = tracks.map((e) => e.key).toSet();
      tracks = [...tracks, ...result.tracks.where((e) => keys.add(e.key))];
      nextPage = result.nextPage;
    } catch (e) {
      if (!_disposed && generation == _generation) error = e.toString();
    }
    if (_disposed || generation != _generation) return;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
