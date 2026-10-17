package com.kafeyn.undertune;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/** Extraction/download channels belong to the media engine, not its window. */
final class BackendPlugin implements FlutterPlugin {
    private ExtractorBridge extractor;
    private DownloadsBridge downloads;
    @Override public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        extractor = new ExtractorBridge(binding.getBinaryMessenger());
        downloads = new DownloadsBridge(binding.getApplicationContext(), binding.getBinaryMessenger());
    }
    @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        extractor.close();
        downloads.close();
    }
}
