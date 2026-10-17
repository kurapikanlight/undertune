package com.kafeyn.undertune;

import io.flutter.plugin.common.MethodCall;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.junit.Assume.assumeTrue;
import org.schabi.newpipe.extractor.NewPipe;
import java.util.*;

/** Opt-in contract checks against the exact bridge shipped to Flutter. */
public class VideoCatalogLiveTest {
    private static Map call(VideoCatalogBridge bridge, String method, Map<String,Object> args) throws Exception {
        return (Map) bridge.handle(new MethodCall(method, args));
    }
    @Test public void channelMetadataServerSortAndPagination() throws Exception {
        assumeTrue("1".equals(System.getenv("UNDERTUNE_LIVE_TEST")));
        NewPipe.init(new ExtractorDownloader());
        var bridge = new VideoCatalogBridge();
        for (String url : List.of("https://www.youtube.com/@mkbhd", "https://www.youtube.com/@LofiGirl")) {
            Map channel = call(bridge, "videoChannel", Map.of("url", url, "serviceId", 0));
            assertTrue(((String) channel.get("id")).startsWith("UC"));
            assertTrue(((String) channel.get("url")).contains("/channel/UC"));
            assertFalse(((String) channel.get("name")).isBlank());
            String canonical = (String) channel.get("url");
            Map latest = call(bridge, "videoChannelItems", Map.of("url", canonical, "serviceId", 0, "tab", "videos", "sort", "latest"));
            assertFalse(((List) latest.get("items")).isEmpty());
            Map popular = call(bridge, "videoChannelItems", Map.of("url", canonical, "serviceId", 0, "tab", "videos", "sort", "popular"));
            assertFalse(((List) popular.get("items")).isEmpty());
            System.out.println("CHANNEL " + channel.get("name") + " id=" + channel.get("id") + " latest=" + ((List) latest.get("items")).get(0) + " popular=" + ((List) popular.get("items")).get(0));
            if (latest.get("nextPage") != null) {
                Map next = call(bridge, "videoChannelItems", Map.of("url", canonical, "serviceId", 0, "tab", "videos", "sort", "latest", "page", latest.get("nextPage")));
                assertFalse(((List) next.get("items")).isEmpty());
                try {
                    call(bridge, "videoChannelItems", Map.of("url", canonical, "serviceId", 0, "tab", "videos", "sort", "popular", "page", latest.get("nextPage")));
                    fail("Continuations must not cross ordering modes");
                } catch (IllegalArgumentException expected) { }
                System.out.println("CHANNEL PAGINATION AND SORT TOKEN ISOLATION PASSED " + channel.get("name"));
            }
            if (((List)channel.get("tabs")).contains("playlists")) {
                Map playlists = call(bridge, "videoChannelItems", Map.of("url", canonical, "serviceId", 0, "tab", "playlists", "sort", "latest"));
                System.out.println("CHANNEL PLAYLISTS " + channel.get("name") + " count=" + ((List)playlists.get("playlists")).size());
            }
        }
    }
    @Test public void filteredSearchAndRealVideoPlaylists() throws Exception {
        assumeTrue("1".equals(System.getenv("UNDERTUNE_LIVE_TEST")));
        NewPipe.init(new ExtractorDownloader());
        var bridge = new VideoCatalogBridge();
        Map channels = call(bridge, "videoChannels", Map.of("query", "NASA", "serviceId", 0));
        assertFalse(((List) channels.get("channels")).isEmpty());
        for (String query : List.of("NASA documentaries", "Marques Brownlee reviews")) {
            Map results = call(bridge, "videoPlaylists", Map.of("query", query, "serviceId", 0));
            assertFalse(((List) results.get("playlists")).isEmpty());
            Map source = (Map) ((List)results.get("playlists")).get(0);
            Map playlist = call(bridge, "videoPlaylist", Map.of("url", source.get("url"), "serviceId", 0));
            assertNotNull(playlist.get("playlist"));
            assertFalse(((List)playlist.get("items")).isEmpty());
            System.out.println("PLAYLIST " + playlist.get("playlist") + " loaded=" + ((List)playlist.get("items")).size());
            if (playlist.get("nextPage") != null) {
                Map next = call(bridge, "videoPlaylist", Map.of("url", source.get("url"), "serviceId", 0, "page", playlist.get("nextPage")));
                assertFalse(((List)next.get("items")).isEmpty());
                System.out.println("PLAYLIST PAGINATION PASSED " + source.get("name"));
            }
        }
    }
}
