package com.kafeyn.undertune;
import org.schabi.newpipe.extractor.StreamingService;
import org.schabi.newpipe.extractor.linkhandler.SearchQueryHandler;
import org.schabi.newpipe.extractor.search.filter.FilterItem;
import org.schabi.newpipe.extractor.exceptions.ParsingException;
import java.util.Collections;

final class PipePipeSearch {
    static SearchQueryHandler query(StreamingService service, String text) throws ParsingException {
        return query(service, text, "videos");
    }
    // Upstream shares mutable filter state; only handler construction needs serialization.
    static synchronized SearchQueryHandler query(StreamingService service, String text, String kind) throws ParsingException {
        final var factory = service.getSearchQHFactory();
        for (var group : factory.getAvailableContentFilter().getFilterGroups()) {
            for (FilterItem item : group.filterItems) {
                if (kind.equals(item.getName())) {
                    return factory.fromQuery(text, Collections.singletonList(item), Collections.emptyList());
                }
            }
        }
        throw new ParsingException("Upstream search filter is unavailable");
    }
}
