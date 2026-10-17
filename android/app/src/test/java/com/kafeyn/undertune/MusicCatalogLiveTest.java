package com.kafeyn.undertune;
import io.flutter.plugin.common.MethodCall;
import org.junit.Test;
import static org.junit.Assert.*;
import static org.junit.Assume.assumeTrue;
import org.schabi.newpipe.extractor.NewPipe;
import java.util.*;
public class MusicCatalogLiveTest {
    @Test public void totoCameleonAlbumAndTracks() throws Exception {
        assumeTrue("1".equals(System.getenv("UNDERTUNE_LIVE_TEST")));
        NewPipe.init(new ExtractorDownloader());
        var bridge = new VideoCatalogBridge();
        Map albums = (Map) bridge.handle(new MethodCall("musicAlbums", Map.of("query", "toto cameleon", "serviceId", 0)));
        System.out.println("TOTO CAMELEON MUSIC ALBUMS " + albums.get("playlists"));
        assertFalse("Official music album search must return albums", ((List)albums.get("playlists")).isEmpty());
        Map album = (Map) ((List)albums.get("playlists")).get(0);
        Map tracks = (Map) bridge.handle(new MethodCall("musicPlaylist", Map.of("url", album.get("url"), "serviceId", 0)));
        System.out.println("ALBUM CONTENTS " + tracks.get("playlist") + " tracks=" + ((List)tracks.get("items")).size());
        assertFalse(((List)tracks.get("items")).isEmpty());
    }
}
