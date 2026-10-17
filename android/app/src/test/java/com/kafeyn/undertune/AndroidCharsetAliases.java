package com.kafeyn.undertune;
import java.nio.charset.*;
import java.nio.charset.spi.CharsetProvider;
import java.util.*;

/** Match Android libcore's UTF_8 alias in opt-in desktop JVM extractor checks. */
public class AndroidCharsetAliases extends CharsetProvider {
    @Override public Iterator<Charset> charsets() { return Collections.singleton(StandardCharsets.UTF_8).iterator(); }
    @Override public Charset charsetForName(String name) { return "UTF_8".equalsIgnoreCase(name) ? StandardCharsets.UTF_8 : null; }
}
