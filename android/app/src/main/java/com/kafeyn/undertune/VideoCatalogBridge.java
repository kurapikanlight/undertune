package com.kafeyn.undertune;

import io.flutter.plugin.common.MethodCall;
import org.schabi.newpipe.extractor.*;
import org.schabi.newpipe.extractor.channel.*;
import org.schabi.newpipe.extractor.playlist.*;
import org.schabi.newpipe.extractor.search.SearchInfo;
import org.schabi.newpipe.extractor.linkhandler.*;
import org.schabi.newpipe.extractor.search.filter.FilterItem;
import java.util.*;

/** Provider discovery and collections; continuations scoped by resource and ordering. */
final class VideoCatalogBridge {
    private final Map<String, Page> pages = new LinkedHashMap<>();
    boolean supports(String method) {
        return Set.of("videoChannels", "videoPlaylists", "videoChannel", "videoChannelItems", "videoPlaylist", "musicAlbums", "musicPlaylists", "musicPlaylist").contains(method);
    }
    Object handle(MethodCall call) throws Exception {
        Number serviceId = call.argument("serviceId");
        if (serviceId != null && serviceId.intValue() != 0) throw new IllegalArgumentException("This video provider is not supported");
        StreamingService service = NewPipe.getService(0);
        String token = call.argument("page");
        if (Set.of("videoChannels", "videoPlaylists", "musicAlbums", "musicPlaylists").contains(call.method)) {
            String query = call.argument("query");
            if (query == null || query.trim().isEmpty() || query.length() > 500) throw new IllegalArgumentException("Enter a search query");
            String filter = call.method.equals("videoChannels") ? "channels" : call.method.equals("musicAlbums") ? "music_albums" : call.method.equals("musicPlaylists") ? "music_playlists" : "playlists";
            var handler = PipePipeSearch.query(service, query, filter);
            String scope = "search:" + filter + ":" + query;
            if (token == null) {
                var info = SearchInfo.getInfo(service, handler);
                check(info);
                return page(scope, info.getRelatedItems(), info.getNextPage());
            }
            var info = SearchInfo.getMoreItems(service, handler, continuation(scope, token));
            checkPage(info);
            return page(scope, info.getItems(), info.getNextPage());
        }
        String url = call.argument("url");
        if (url == null || !url.startsWith("https://")) throw new IllegalArgumentException("Invalid video source");
        if (call.method.equals("videoChannel")) {
            service.getChannelLHFactory().fromUrl(url);
            var info = ChannelInfo.getInfo(service, url);
            Map<String,Object> data = identity(info.getId(), info.getUrl(), info.getName());
            data.put("artwork", info.getAvatarUrl()); data.put("banner", info.getBannerUrl());
            data.put("description", info.getDescription()); data.put("subscribers", info.getSubscriberCount());
            List<String> tabs = new ArrayList<>();
            for (var tab : info.getTabs()) for (var filter : tab.getContentFilters()) tabs.add(filter.getName());
            // The legacy initial channel page can expose videos without a separate tab.
            if (!info.getRelatedItems().isEmpty() && !tabs.contains(ChannelTabs.VIDEOS)) tabs.add(ChannelTabs.VIDEOS);
            data.put("tabs", tabs);
            data.put("sorts", Arrays.asList("latest", "popular"));
            return data;
        }
        if (call.method.equals("videoChannelItems")) {
            String tab = call.argument("tab"), sort = call.argument("sort");
            if (!Set.of("videos", "playlists").contains(tab) || !Set.of("latest", "popular").contains(sort)) throw new IllegalArgumentException("Unsupported channel ordering");
            if (tab.equals("playlists") && !sort.equals("latest")) throw new IllegalArgumentException("Playlist ordering is not supported");
            var factory = service.getChannelTabLHFactory();
            var sorts = new ArrayList<FilterItem>();
            if (tab.equals("videos")) {
                for (var group : factory.getAvailableSortFilter().getFilterGroups())
                    for (var filter : group.filterItems) if (sort.equals(filter.getName())) sorts.add(filter);
                if (sorts.isEmpty()) throw new IllegalArgumentException("This ordering is not available for this provider");
            }
            var handler = factory.fromQuery(service.getChannelLHFactory().getId(url),
                Collections.singletonList(new FilterItem(-1, tab)), sorts);
            String scope = "channel:" + handler.getUrl() + ":" + tab + ":" + sort;
            if (token == null) {
                var info = ChannelTabInfo.getInfo(service, handler);
                check(info);
                return page(scope, info.getRelatedItems(), info.getNextPage());
            }
            var info = ChannelTabInfo.getMoreItems(service, handler, continuation(scope, token));
            checkPage(info);
            return page(scope, info.getItems(), info.getNextPage());
        }
        service.getPlaylistLHFactory().fromUrl(url);
        String scope = call.method + ":" + service.getPlaylistLHFactory().getId(url);
        if (token != null) {
            var info = PlaylistInfo.getMoreItems(service, url, continuation(scope, token));
            checkPage(info);
            return page(scope, info.getItems(), info.getNextPage());
        }
        var info = PlaylistInfo.getInfo(service, url);
        check(info);
        Map<String,Object> data = page(scope, info.getRelatedItems(), info.getNextPage());
        Map<String,Object> playlist = identity(info.getId(), info.getUrl(), info.getName());
        playlist.put("artwork", info.getThumbnailUrl()); playlist.put("artist", info.getUploaderName());
        playlist.put("count", info.getStreamCount());
        data.put("playlist", playlist);
        return data;
    }
    private static void checkPage(ListExtractor.InfoItemsPage<?> info) throws Exception {
        if (info.getItems().isEmpty() && !info.getErrors().isEmpty()) {
            throw new Exception("Could not load the next page", info.getErrors().get(0));
        }
    }
    private static void check(ListInfo<?> info) throws Exception {
        if (info.getRelatedItems().isEmpty() && !info.getErrors().isEmpty()) {
            throw new Exception("Could not load this list or ordering", info.getErrors().get(0));
        }
    }
    private synchronized Page continuation(String scope, String token) {
        Page page = pages.get(scope + ":" + token);
        if (page == null) throw new IllegalArgumentException("This list expired. Refresh it to continue.");
        return page;
    }
    private synchronized Map<String,Object> page(String scope, List<? extends InfoItem> items, Page next) throws Exception {
        Map<String,Object> data = new HashMap<>();
        data.put("items", ExtractorBridge.tracks(items));
        List<Map<String,Object>> channels = new ArrayList<>(), playlists = new ArrayList<>();
        var service = NewPipe.getService(0);
        for (var item : items) {
            if (item instanceof ChannelInfoItem c) {
                // Extractor search URLs carry stable UC identifiers; handles resolve on the detail page.
                String id = c.getUploaderId();
                if (id == null || id.isEmpty()) id = service.getChannelLHFactory().getId(c.getUrl()).replaceFirst("^channel/", "");
                var channel = identity(id.replaceFirst("^channel/", ""), c.getUrl(), c.getName());
                channel.put("artwork", c.getThumbnailUrl()); channel.put("description", c.getDescription());
                channel.put("subscribers", c.getSubscriberCount()); channels.add(channel);
            } else if (item instanceof PlaylistInfoItem p) {
                var playlist = identity(service.getPlaylistLHFactory().getId(p.getUrl()), p.getUrl(), p.getName());
                playlist.put("artwork", p.getThumbnailUrl()); playlist.put("artist", p.getUploaderName());
                playlist.put("count", p.getStreamCount()); playlists.add(playlist);
            }
        }
        data.put("channels", channels); data.put("playlists", playlists);
        String token = null;
        if (Page.isValid(next)) {
            token = UUID.randomUUID().toString();
            if (pages.size() >= 128) pages.remove(pages.keySet().iterator().next());
            pages.put(scope + ":" + token, next);
        }
        data.put("nextPage", token);
        return data;
    }
    private static Map<String,Object> identity(String id, String url, String name) {
        Map<String,Object> item = new HashMap<>();
        item.put("id", id); item.put("url", url); item.put("name", name); item.put("serviceId", 0);
        return item;
    }
    synchronized void clear() { pages.clear(); }
}
