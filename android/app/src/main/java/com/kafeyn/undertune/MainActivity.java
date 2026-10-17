package com.kafeyn.undertune;

import androidx.annotation.NonNull;
import android.content.Intent;
import com.ryanheise.audioservice.AudioServiceActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends AudioServiceActivity {
    private PlaylistImagesBridge playlistImages;
    @Override public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        if (!engine.getPlugins().has(BackendPlugin.class)) {
            engine.getPlugins().add(new BackendPlugin());
        }
        playlistImages = new PlaylistImagesBridge(this, engine.getDartExecutor().getBinaryMessenger());
    }
    @Override public void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (playlistImages != null) playlistImages.onActivityResult(requestCode, resultCode, data);
    }
    @Override public void cleanUpFlutterEngine(@NonNull FlutterEngine engine) {
        if (playlistImages != null) playlistImages.close();
        super.cleanUpFlutterEngine(engine);
    }
}
