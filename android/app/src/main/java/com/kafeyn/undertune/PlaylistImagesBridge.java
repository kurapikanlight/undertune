package com.kafeyn.undertune;

import android.app.Activity;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.net.Uri;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Uses the system file picker; stores a private copy independent of URI grants. */
final class PlaylistImagesBridge implements AutoCloseable {
    private static final int REQUEST_IMAGE = 8241;
    private final Activity activity;
    private final MethodChannel channel;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private MethodChannel.Result pending;
    private boolean closed;

    PlaylistImagesBridge(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;
        channel = new MethodChannel(messenger, "undertune/playlist_images");
        channel.setMethodCallHandler((call, result) -> {
            if (!"pick".equals(call.method)) { result.notImplemented(); return; }
            if (pending != null) { result.error("busy", "An image picker is already open.", null); return; }
            pending = result;
            try {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.setType("image/*");
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                activity.startActivityForResult(intent, REQUEST_IMAGE);
            } catch (Exception e) {
                pending = null;
                result.error("picker", "Could not open the image picker.", null);
            }
        });
    }

    void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQUEST_IMAGE || pending == null) return;
        final MethodChannel.Result result = pending;
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            pending = null;
            result.success(null);
            return;
        }
        final Uri uri = data.getData();
        worker.execute(() -> {
            File output = null;
            try {
                final BitmapFactory.Options options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                try (InputStream input = activity.getContentResolver().openInputStream(uri)) {
                    BitmapFactory.decodeStream(input, null, options);
                }
                if (options.outWidth <= 0 || options.outHeight <= 0) throw new IllegalArgumentException("Invalid image");
                File directory = new File(activity.getFilesDir(), "playlist_covers");
                if (!directory.isDirectory() && !directory.mkdirs()) throw new IllegalStateException("Could not create cover directory");
                output = new File(directory, UUID.randomUUID() + ".image");
                // Preserve image orientation/format; Flutter decodes at a bounded size.
                try (InputStream input = activity.getContentResolver().openInputStream(uri);
                     FileOutputStream stream = new FileOutputStream(output)) {
                    if (input == null) throw new IllegalArgumentException("Unreadable image");
                    byte[] buffer = new byte[8192];
                    int count, total = 0;
                    while ((count = input.read(buffer)) != -1) {
                        total += count;
                        if (total > 20 * 1024 * 1024) throw new IllegalArgumentException("Image exceeds 20 MB");
                        stream.write(buffer, 0, count);
                    }
                }
                final String path = output.getAbsolutePath();
                activity.runOnUiThread(() -> { pending = null; if (!closed) result.success(path); });
            } catch (Exception e) {
                if (output != null) output.delete();
                activity.runOnUiThread(() -> { pending = null; if (!closed) result.error("image", "Could not save that image.", null); });
            }
        });
    }

    @Override public void close() {
        closed = true;
        channel.setMethodCallHandler(null);
        pending = null;
        worker.shutdown();
    }
}
