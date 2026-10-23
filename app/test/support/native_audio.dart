import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercise the real just_audio and Playback through their native channel.
class NativeAudio {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final players = <String, NativeAudioPlayer>{};
  final sources = <String>[];
  NativeAudioPlayer get current => players.values.lastWhere((p) => !p.disposed);
  static const main = MethodChannel('com.ryanheise.just_audio.methods');
  NativeAudio() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => call.method == 'setActive' ? true : null,
    );
    messenger.setMockMethodCallHandler(main, (call) async {
      final id = call.arguments?['id'] as String?;
      if (call.method == 'init') {
        players[id!] = NativeAudioPlayer(this, id);
      } else if (call.method == 'disposePlayer') {
        players[id]?.disposed = true;
      }
      return <String, dynamic>{};
    });
  }
  void dispose() {
    messenger.setMockMethodCallHandler(main, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      null,
    );
    for (final id in players.keys) {
      for (final prefix in ['methods', 'events', 'data']) {
        messenger.setMockMethodCallHandler(
          MethodChannel('com.ryanheise.just_audio.$prefix.$id'),
          null,
        );
      }
    }
  }
}

class NativeAudioPlayer {
  NativeAudioPlayer(this.host, this.id) {
    host.messenger.setMockMethodCallHandler(
      MethodChannel('com.ryanheise.just_audio.events.$id'),
      (_) async => null,
    );
    host.messenger.setMockMethodCallHandler(
      MethodChannel('com.ryanheise.just_audio.data.$id'),
      (_) async => null,
    );
    host.messenger.setMockMethodCallHandler(
      MethodChannel('com.ryanheise.just_audio.methods.$id'),
      (call) async {
        switch (call.method) {
          case 'load':
            String? uri(dynamic source) =>
                source['uri'] as String? ??
                (source['children'] is List &&
                        (source['children'] as List).isNotEmpty
                    ? uri(source['children'][0])
                    : null);
            host.sources.add(uri(call.arguments['audioSource']) ?? 'unknown');
            position = Duration.zero;
            event(3);
            return {'duration': const Duration(seconds: 30).inMicroseconds};
          case 'seek':
            seeks++;
            final target = call.arguments['position'] as int? ?? 0;
            if (seekGate != null) await seekGate!.future;
            position = Duration(microseconds: target);
            event(3);
          case 'pause':
            pauses++;
          case 'play':
            plays++;
        }
        return <String, dynamic>{};
      },
    );
  }
  final NativeAudio host;
  final String id;
  bool disposed = false;
  int seeks = 0, pauses = 0, plays = 0;
  Duration position = Duration.zero;
  Completer<void>? seekGate;
  void finish() {
    position = const Duration(seconds: 30);
    event(4);
  }

  void event(int state) {
    if (disposed) return;
    // ignore: deprecated_member_use
    host.messenger.handlePlatformMessage(
      'com.ryanheise.just_audio.events.$id',
      const StandardMethodCodec().encodeSuccessEnvelope({
        'processingState': state,
        'updateTime': DateTime.now().millisecondsSinceEpoch,
        'updatePosition': position.inMicroseconds,
        'bufferedPosition': const Duration(seconds: 30).inMicroseconds,
        'duration': const Duration(seconds: 30).inMicroseconds,
        'currentIndex': 0,
      }),
      (_) {},
    );
  }
}

Future<void> flushAudio() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
