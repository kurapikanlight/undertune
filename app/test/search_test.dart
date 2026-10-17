import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/media/extractor.dart';
import 'package:undertune/media/search.dart';

class DelayedExtractor extends Extractor {
  final requests = <String, Completer<SearchPage>>{};
  @override
  Future<SearchPage> search(String query, {String? page}) =>
      (requests[query] = Completer<SearchPage>()).future;
}

void main() {
  test('obsolete response cannot replace latest query', () async {
    final api = DelayedExtractor();
    final search = SearchResults(api);
    final old = search.submit('old');
    final latest = search.submit('new');
    api.requests['new']!.complete(
      SearchPage([const Track(url: 'new', title: 'New', artist: '')], null),
    );
    await latest;
    api.requests['old']!.complete(
      SearchPage([const Track(url: 'old', title: 'Old', artist: '')], null),
    );
    await old;
    expect(search.tracks.single.url, 'new');
    expect(search.loading, false);
  });
}
