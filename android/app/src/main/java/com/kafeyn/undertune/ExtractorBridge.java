package com.kafeyn.undertune;

import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.schabi.newpipe.extractor.*;
import org.schabi.newpipe.extractor.downloader.*;
import org.schabi.newpipe.extractor.search.SearchInfo;
import org.schabi.newpipe.extractor.stream.*;
import java.net.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** App-owned adapter; no Flutter or Undertune modifications are made upstream. */
final class ExtractorBridge implements AutoCloseable {
    private final ExecutorService workers = Executors.newFixedThreadPool(3);
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String, Page> pages = Collections.synchronizedMap(new LinkedHashMap<>());
    private final MethodChannel channel;
    private volatile boolean closed;
    private final VideoCatalogBridge catalog = new VideoCatalogBridge();
    ExtractorBridge(BinaryMessenger messenger) {
        NewPipe.init(new ExtractorDownloader());
        channel = new MethodChannel(messenger, "undertune/extractor");
        channel.setMethodCallHandler(this::handle);
    }
    private void handle(MethodCall call, MethodChannel.Result reply) {
        workers.execute(() -> {
            try {
                Object value;
                String query = call.argument("query");
                if (catalog.supports(call.method)) {
                    value = catalog.handle(call);
                } else if ("search".equals(call.method)) {
                    if (query == null || query.trim().isEmpty() || query.length() > 500) throw new IllegalArgumentException("Enter a search query");
                    final StreamingService service = NewPipe.getService(0);
                    final var handler = PipePipeSearch.query(service, query);
                    final String token = call.argument("page");
                    List<InfoItem> items; Page next;
                    if (token == null) {
                        final SearchInfo info = SearchInfo.getInfo(service, handler);
                        items = info.getRelatedItems(); next = info.getNextPage();
                    } else {
                        Page page = pages.get(query + ":" + token);
                        if (page == null) throw new IllegalArgumentException("Search page expired. Search again.");
                        var info = SearchInfo.getMoreItems(service, handler, page);
                        items = info.getItems(); next = info.getNextPage();
                    }
                    String nextToken = null;
                    if (Page.isValid(next)) {
                        nextToken = UUID.randomUUID().toString();
                        synchronized (pages) {
                            if (pages.size() >= 64) pages.remove(pages.keySet().iterator().next());
                            pages.put(query + ":" + nextToken, next);
                        }
                    }
                    Map<String,Object> data = new HashMap<>();
                    data.put("items", tracks(items)); data.put("nextPage", nextToken); value = data;
                } else if ("suggestions".equals(call.method)) {
                    if (query == null || query.length() > 500) throw new IllegalArgumentException("Invalid query");
                    value = NewPipe.getService(0).getSuggestionExtractor().suggestionList(query);
                } else if ("resolve".equals(call.method)) {
                    final String url = call.argument("url");
                    final Number serviceId = call.argument("serviceId");
                    if (serviceId == null || serviceId.intValue() != 0 || url == null || !url.startsWith("https://")) throw new IllegalArgumentException("Unsupported media link");
                    StreamInfo info = StreamInfo.getInfo(NewPipe.getService(0), url);
                    Map<String,Object> data = new HashMap<>();
                    data.put("live", isLive(info.getStreamType()));
                    List<Map<String,Object>> audio = new ArrayList<>(), video = new ArrayList<>();
                    for (AudioStream s : info.getAudioStreams()) {
                        if (s.isUrl() && s.getDeliveryMethod() != DeliveryMethod.SABR) {
                            Map<String,Object> stream = new HashMap<>();
                            stream.put("url", s.getContent());
                            stream.put("extension", s.getFormat() == null ? "bin" : s.getFormat().suffix);
                            stream.put("mime", s.getFormat() == null ? "application/octet-stream" : s.getFormat().mimeType);
                            stream.put("hls", s.getDeliveryMethod() == DeliveryMethod.HLS);
                            stream.put("bitrate", s.getAverageBitrate()); audio.add(stream);
                        }
                    }
                    audio.sort((a,b) -> Integer.compare((int)b.get("bitrate"),(int)a.get("bitrate")));
                    video.addAll(videoStreams(info.getVideoStreams()));
                    data.put("audio", audio); data.put("video",video);
                    if (Boolean.TRUE.equals(call.argument("video"))) data.put("videoOnly", videoStreams(info.getVideoOnlyStreams()));
                    if (video.isEmpty() && Boolean.TRUE.equals(call.argument("video"))) {
                        try { data.put("dash", VideoManifest.create(info)); }
                        catch (Exception ignored) { data.put("dash", null); }
                    } data.put("hls", info.getHlsUrl());
                    data.put("channelUrl",info.getUploaderUrl()); data.put("channelArtwork",info.getUploaderAvatarUrl());
                    data.put("title",info.getName()); data.put("artist",info.getUploaderName());
                    data.put("artwork",info.getThumbnailUrl()); data.put("duration",info.getDuration());
                    data.put("related",tracks(info.getRelatedItems())); value = data;
                } else { main.post(reply::notImplemented); return; }
                main.post(() -> { if (!closed) reply.success(value); });
            } catch (Exception error) {
                main.post(() -> { if (!closed) reply.error("EXTRACTION_FAILED", error.getMessage() == null ? "Media service unavailable" : error.getMessage(), null); });
            }
        });
    }
    private static boolean isLive(StreamType type) {return type==StreamType.LIVE_STREAM||type==StreamType.AUDIO_LIVE_STREAM;}
    private static List<Map<String,Object>> videoStreams(List<VideoStream> streams) {
        List<Map<String,Object>> result = new ArrayList<>();
        for (VideoStream s : streams) {
            if (!s.isUrl() || s.getDeliveryMethod() == DeliveryMethod.SABR || s.getDeliveryMethod() == DeliveryMethod.HLS) continue;
            Map<String,Object> item = new HashMap<>();
            item.put("url",s.getContent()); item.put("quality",s.getResolution()); item.put("codec",s.getCodec());
            item.put("extension",s.getFormat() == null ? "bin" : s.getFormat().suffix);
            item.put("mime",s.getFormat() == null ? "application/octet-stream" : s.getFormat().mimeType);
            result.add(item);
        }
        return result;
    }
    static List<Map<String,Object>> tracks(List<? extends InfoItem> items) {
        List<Map<String,Object>> result = new ArrayList<>();
        for (InfoItem item : items) if (item instanceof StreamInfoItem) {
            StreamInfoItem stream = (StreamInfoItem)item;
            Map<String,Object> track = new HashMap<>(); track.put("url",stream.getUrl());
            track.put("title",stream.getName()); track.put("artist",stream.getUploaderName());
            track.put("artwork",stream.getThumbnailUrl()); track.put("duration",stream.getDuration());
            track.put("serviceId",stream.getServiceId()); result.add(track);
            track.put("live",isLive(stream.getStreamType()));
            track.put("channelUrl", stream.getUploaderUrl());
            track.put("channelArtwork", stream.getUploaderAvatarUrl());
            track.put("views", stream.getViewCount());
            if (stream.getUploadDate() != null) track.put("publishedAt", stream.getUploadDate().offsetDateTime().toInstant().toEpochMilli());
        }
        return result;
    }
    @Override public void close() { closed = true; channel.setMethodCallHandler(null); workers.shutdownNow(); pages.clear(); catalog.clear(); }
}
