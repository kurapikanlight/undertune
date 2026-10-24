<p align="center">
  <img src="app/assets/branding/icon.png" alt="Undertune app icon" width="144" height="144">
</p>
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/undertune-wordmark-light.svg">
    <img src="docs/assets/undertune-wordmark-dark.svg" alt="Undertune" width="280">
  </picture>
</p>
<p align="center">
  A music and video app for Android.<br>
  <strong>Version 1 · Android ready</strong>
</p>

Undertune lets you listen to music, watch videos, and keep your favorites together. Built with Flutter and powered by PipePipeExtractor, with separate music and video players and favorites.

- Search for songs, albums, playlists, and videos.
- Create playlists, save albums, and follow video channels.
- Keep listening in the background or with your screen locked.
- Download audio and videos for offline playback, and automatically download new songs added to enabled playlists.
- Make it yours with animated themes and custom playlist covers.

Download the APK, then open it on your Android phone to install Undertune.

<p align="center">
  <a href="https://github.com/kurapikanlight/undertune/releases/download/v1.0.1/Undertune.apk">
    <img src="docs/assets/download-android.svg" alt="Download Undertune for Android" width="300" height="56">
  </a>
  <br>
  <sub>Version 1.0.0 · Android APK</sub>
</p>

### Open-source credits

Thanks to the developers and contributors behind these projects:

| Project | Used for |
| --- | --- |
| [Flutter](https://github.com/flutter/flutter) and [Dart](https://github.com/dart-lang/sdk) | The app interface and language. |
| [PipePipe](https://github.com/InfinityLoop1308/PipePipe) / [PipePipeExtractor](https://github.com/InfinityLoop1308/PipePipeExtractor) | Finding music and videos and extracting media streams. |
| [NewPipe](https://github.com/TeamNewPipe/NewPipe) / [NewPipeExtractor](https://github.com/TeamNewPipe/NewPipeExtractor) | The original foundation of the extractor. |
| [just_audio](https://github.com/ryanheise/just_audio) | Music playback. |
| [audio_service](https://github.com/ryanheise/audio_service) and [audio_session](https://github.com/ryanheise/audio_session) | Background playback, media controls, and audio focus. |
| [video_player](https://github.com/flutter/packages/tree/main/packages/video_player) | Video playback. |
| [shared_preferences](https://github.com/flutter/packages/tree/main/packages/shared_preferences) | Saving settings and library data. |
| [url_launcher](https://github.com/flutter/packages/tree/main/packages/url_launcher) | Opening external links. |
| [crypto](https://github.com/dart-lang/core/tree/main/pkgs/crypto) | Hashing utilities. |
| [OkHttp](https://github.com/square/okhttp) | Network requests. |

The bundled extractor and its `timeago-parser` files come from PipePipeExtractor. Its source revision is recorded in [the backend lock file](vendor/pipepipe.lock.json), and its GPL-3.0 license is included [here](app/assets/licenses/PipePipeExtractor.txt). Package versions are recorded in [pubspec.lock](app/pubspec.lock); package licenses are also available inside **About → Package licenses**.

### Font and branding

The app icon is included in [app/assets/branding](app/assets/branding). The README wordmark uses the app’s bundled [Feelfree font](app/assets/fonts/Feelfree-Regular.ttf) by [Billy Argel](https://billyargel.com/product/feelfree/), originally downloaded from [font.download](https://font.download/font/feelfree-personal-use). Feelfree is **personal use only**, with its own [font credit and license](app/assets/licenses/Feelfree.txt).

For build instructions and backend updates, see the [development guide](docs/DEVELOPMENT.md).

<p align="center">Made by <a href="https://github.com/kurapikanlight">Kafeyn</a></p>
