package com.kafeyn.undertune;
import org.schabi.newpipe.extractor.downloader.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;
final class ExtractorDownloader extends Downloader {
        private final okhttp3.OkHttpClient client = new okhttp3.OkHttpClient.Builder()
            .connectTimeout(20, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS).build();
        private okhttp3.Call call(Request request) {
            okhttp3.Request.Builder builder = new okhttp3.Request.Builder().url(request.url())
                .header("User-Agent", "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/130.0.0.0 Mobile Safari/537.36");
            for (var header : request.headers().entrySet()) {
                builder.removeHeader(header.getKey());
                for (String value : header.getValue()) builder.addHeader(header.getKey(), value);
            }
            byte[] data = request.dataToSend();
            okhttp3.RequestBody body = data != null ? okhttp3.RequestBody.create(data, (okhttp3.MediaType)null)
                : (request.httpMethod().equals("POST") || request.httpMethod().equals("PUT"))
                    ? okhttp3.RequestBody.create(new byte[0], (okhttp3.MediaType)null) : null;
            builder.method(request.httpMethod(), body);
            return (request.followRedirects() ? client : client.newBuilder().followRedirects(false).build()).newCall(builder.build());
        }
        private Response convert(okhttp3.Response response) throws IOException {
            try (response) {
                byte[] bytes = response.body() == null ? new byte[0] : response.body().bytes();
                return new Response(response.code(),response.message(),response.headers().toMultimap(),
                    new String(bytes,StandardCharsets.UTF_8),bytes,response.request().url().toString());
            }
        }
        @Override public Response execute(Request request) throws IOException { return convert(call(request).execute()); }
        @Override public CancellableCall executeAsync(Request request, AsyncCallback callback) {
            okhttp3.Call call = call(request);
            CancellableCall cancellable = new CancellableCall(call);
            call.enqueue(new okhttp3.Callback() {
                @Override public void onFailure(okhttp3.Call c, IOException e) { try {callback.onError(e);} finally {cancellable.setFinished();} }
                @Override public void onResponse(okhttp3.Call c, okhttp3.Response r) {
                    try {callback.onSuccess(convert(r));} catch(Exception e) {callback.onError(e);} finally {cancellable.setFinished();}
                }
            });
            return cancellable;
        }
    }
