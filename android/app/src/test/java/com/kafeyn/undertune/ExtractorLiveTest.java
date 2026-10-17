package com.kafeyn.undertune;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.junit.Assume.assumeTrue;
import org.schabi.newpipe.extractor.*;
import org.schabi.newpipe.extractor.search.SearchInfo;
import org.schabi.newpipe.extractor.stream.*;

/** Opt-in live contract check; ordinary offline builds do not depend on YouTube availability. */
public class ExtractorLiveTest {
    @Test public void realSearchAndStreamExtraction() throws Exception {
        assumeTrue("1".equals(System.getenv("UNDERTUNE_LIVE_TEST")));
        NewPipe.init(new ExtractorDownloader());
        var service = NewPipe.getService(0);
        var results = SearchInfo.getInfo(service, PipePipeSearch.query(service, "lofi music"));
        var track = results.getRelatedItems().stream().filter(i -> i instanceof StreamInfoItem && ((StreamInfoItem)i).getDuration() > 0).findFirst();
        assertTrue("Search must return a real stream", track.isPresent());
        StreamInfo info = StreamInfo.getInfo(service, track.get().getUrl());
        assertFalse("Extraction must return audio", info.getAudioStreams().isEmpty());
        long direct = info.getAudioStreams().stream().filter(s -> s.isUrl() && s.getDeliveryMethod()!=DeliveryMethod.SABR).count();
        System.out.println("LIVE EXTRACTION: audio="+info.getAudioStreams().size()+", direct="+direct+", muxed video="+info.getVideoStreams().size()+", video-only="+info.getVideoOnlyStreams().size());
        assertTrue("The Flutter player needs a direct stream or HLS", direct > 0 || (info.getHlsUrl()!=null && !info.getHlsUrl().isEmpty()));
        if (info.getVideoStreams().isEmpty()) {
            String manifest=VideoManifest.create(info);
            assertNotNull("Separate video/audio streams must produce a DASH manifest",manifest);
            var document = javax.xml.parsers.DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(new org.xml.sax.InputSource(new java.io.StringReader(manifest)));
            var adaptations = document.getElementsByTagName("AdaptationSet");
            assertEquals("Video and audio must each have an adaptation set", 2, adaptations.getLength());
            var ids = new java.util.HashSet<Integer>();
            for (int i=0;i<adaptations.getLength();i++) {
                ids.add(Integer.parseInt(((org.w3c.dom.Element)adaptations.item(i)).getAttribute("id")));
            }
            assertEquals("DASH adaptation IDs must be unique unsigned integers", 2, ids.size());
        }
        if (direct > 0) {
            var stream = info.getAudioStreams().stream().filter(s -> s.isUrl() && s.getDeliveryMethod()!=DeliveryMethod.SABR).findFirst().orElseThrow();
            var client = new okhttp3.OkHttpClient.Builder().callTimeout(30, java.util.concurrent.TimeUnit.SECONDS).build();
            var request = new okhttp3.Request.Builder().url(stream.getContent()).header("Range", "bytes=0-4095").build();
            try (var response = client.newCall(request).execute()) {
                assertTrue("Audio endpoint must accept the resolved URL; HTTP " + response.code(), response.isSuccessful());
                assertNotNull(response.body());
                assertTrue("Audio bytes must be available", response.body().byteStream().readNBytes(4096).length > 0);
            }
        }
    }
}
