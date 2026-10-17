import 'package:flutter_test/flutter_test.dart';
import 'package:undertune/media/segments.dart';

void main() {
  test('only valid configured segments skip once within their bounds', () {
    final skipper = SegmentSkipper([
      {
        'UUID': 'a',
        'category': 'sponsor',
        'segment': [10, 20],
      },
      {
        'UUID': 'bad',
        'category': 'sponsor',
        'segment': [30, 20],
      },
      {
        'UUID': 'intro',
        'category': 'intro',
        'segment': [40, 50],
      },
    ]);
    expect(skipper.target(const Duration(seconds: 9)), isNull);
    expect(
      skipper.target(const Duration(seconds: 11)),
      const Duration(seconds: 20),
    );
    expect(skipper.target(const Duration(seconds: 12)), isNull);
    expect(skipper.target(const Duration(seconds: 45)), isNull);
  });
}
