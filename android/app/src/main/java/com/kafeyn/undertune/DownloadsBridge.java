package com.kafeyn.undertune;

import android.app.DownloadManager;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.*;
import org.json.*;
import java.io.File;
import java.util.*;
import java.util.concurrent.*;

/** DownloadManager owns transfers; completed adaptive parts are assembled when refreshed. */
final class DownloadsBridge implements AutoCloseable {
    private final Context context;
    private final DownloadManager manager;
    private final MethodChannel channel;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    DownloadsBridge(Context context, BinaryMessenger messenger) {
        this.context=context.getApplicationContext();
        manager=(DownloadManager)context.getSystemService(Context.DOWNLOAD_SERVICE);
        channel=new MethodChannel(messenger,"undertune/downloads");
        channel.setMethodCallHandler((call,reply)->worker.execute(()->{
            try {
                Object result;
                switch (call.method) {
                    case "enqueue": result=enqueue(call);break;
                    case "list": result=list();break;
                    case "remove":
                        Number id=call.argument("id");
                        if(id==null)throw new IllegalArgumentException("Missing download ID");
                        JSONArray saved=read(),kept=new JSONArray();JSONObject removed=null;
                        for(int i=0;i<saved.length();i++) {
                            JSONObject entry=saved.getJSONObject(i);
                            if(entry.getLong("id")==id.longValue()) removed=entry; else kept.put(entry);
                        }
                        save(kept);
                        if(removed!=null)removeFiles(removed);
                        result=null;break;
                    default: main.post(reply::notImplemented);return;
                }
                main.post(()->reply.success(result));
            }catch(Exception error){main.post(()->reply.error("DOWNLOAD_FAILED",error.getMessage(),null));}
        }));
    }
    private long enqueue(MethodCall call)throws Exception {
        String url=call.argument("streamUrl"),audioUrl=call.argument("audioUrl"),kind=call.argument("kind");
        Map<String,Object> track=call.argument("track");
        if(!https(url)||track==null||audioUrl!=null&&!https(audioUrl))throw new IllegalArgumentException("Invalid download");
        if(kind==null)kind="audio";
        if(!kind.equals("audio")&&!kind.equals("video")||audioUrl!=null&&!kind.equals("video"))throw new IllegalArgumentException("Invalid download type");
        JSONArray saved=read();String key=track.get("serviceId")+":"+track.get("url");
        for(int i=0;i<saved.length();i++) {
            JSONObject entry=saved.getJSONObject(i);
            if(entry.getString("key").equals(key)&&entry.optString("kind","audio").equals(kind))throw new IllegalStateException("This "+kind+" is already in Downloads.");
        }
        String extension=call.argument("extension");
        if(extension==null||!extension.matches("[a-z0-9]{1,5}"))extension="bin";
        File directory=context.getExternalFilesDir(kind.equals("video")?Environment.DIRECTORY_MOVIES:Environment.DIRECTORY_MUSIC);
        if(directory==null||!directory.isDirectory()&&!directory.mkdirs())throw new IllegalStateException("Download storage unavailable");
        File destination=new File(directory,UUID.randomUUID()+"."+extension);
        JSONObject entry=new JSONObject();
        try {
            File videoPart=audioUrl==null?destination:new File(destination+".video");
            long id=transfer(url,videoPart,String.valueOf(track.get("title")),kind);
            entry.put("id",id);entry.put("key",key);entry.put("track",new JSONObject(track));entry.put("path",destination.getAbsolutePath());
            entry.put("kind",kind);entry.put("quality",call.argument("quality"));
            if(audioUrl!=null) {
                entry.put("videoPath",videoPart.getAbsolutePath());
                File audioPart=new File(destination+".audio");entry.put("audioPath",audioPart.getAbsolutePath());
                entry.put("audioId",transfer(audioUrl,audioPart,String.valueOf(track.get("title")),"video audio"));
            }
            saved.put(entry);save(saved);return id;
        }catch(Exception error){removeFiles(entry);throw error;}
    }
    private long transfer(String url,File file,String title,String kind) {
        return manager.enqueue(new DownloadManager.Request(Uri.parse(url)).setTitle(title).setDescription("Undertune "+kind)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED).setDestinationUri(Uri.fromFile(file)));
    }
    private List<Map<String,Object>> list()throws Exception {
        List<Map<String,Object>> entries=new ArrayList<>();JSONArray saved=read();boolean changed=false;
        for(int i=0;i<saved.length();i++) {
            JSONObject entry=saved.getJSONObject(i);File output=new File(entry.getString("path"));
            boolean adaptive=entry.has("audioId");
            Transfer video=query(entry.getLong("id"));Transfer audio=adaptive?query(entry.getLong("audioId")):null;
            String status=video.status;
            long downloaded=video.bytes+(audio==null?0:audio.bytes),total=video.total+(audio==null?0:audio.total);
            if(adaptive) {
                if(output.isFile()&&output.length()>0) {status="complete";downloaded=total=output.length();}
                else if(entry.has("mergeError"))status="failed";
                else if(video.status.equals("complete")&&audio.status.equals("complete")) {
                    try {
                        VideoDownloadMuxer.merge(entry.getString("videoPath"),entry.getString("audioPath"),output.getAbsolutePath());
                        manager.remove(entry.getLong("id"),entry.getLong("audioId"));
                        new File(entry.getString("videoPath")).delete();new File(entry.getString("audioPath")).delete();
                        status="complete";downloaded=total=output.length();
                    }catch(Exception error){entry.put("mergeError",error.toString());changed=true;status="failed";}
                } else if(video.status.equals("failed")||audio.status.equals("failed"))status="failed";
                else if(video.status.equals("missing")||audio.status.equals("missing"))status="missing";
                else if(video.status.equals("paused")||audio.status.equals("paused"))status="paused";
                else status="downloading";
            } else if(status.equals("complete")&&(!output.isFile()||output.length()==0))status="missing";
            Map<String,Object> item=new HashMap<>();
            item.put("id",entry.getLong("id"));item.put("track",jsonMap(entry.getJSONObject("track")));
            item.put("kind",entry.optString("kind","audio"));item.put("quality",entry.optString("quality",""));
            item.put("status",status);item.put("bytes",downloaded);item.put("total",total);
            item.put("localUrl",status.equals("complete")?Uri.fromFile(output).toString():null);entries.add(item);
        }
        if(changed)save(saved);
        return entries;
    }
    private static class Transfer {String status="missing";long bytes,total;}
    private Transfer query(long id) {
        Transfer value=new Transfer();
        try(Cursor c=manager.query(new DownloadManager.Query().setFilterById(id))) {
            if(c!=null&&c.moveToFirst()) {
                int state=c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
                value.bytes=Math.max(0,c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)));
                value.total=Math.max(0,c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)));
                switch(state) {
                    case DownloadManager.STATUS_SUCCESSFUL:value.status="complete";break;
                    case DownloadManager.STATUS_FAILED:value.status="failed";break;
                    case DownloadManager.STATUS_PAUSED:value.status="paused";break;
                    default:value.status="downloading";
                }
            }
        }
        return value;
    }
    private void removeFiles(JSONObject entry) {
        if(entry.has("id"))manager.remove(entry.optLong("id"));
        if(entry.has("audioId"))manager.remove(entry.optLong("audioId"));
        for(String key:new String[]{"path","videoPath","audioPath"})if(entry.has(key))new File(entry.optString(key)).delete();
        if(entry.has("path"))new File(entry.optString("path")+".assembling").delete();
    }
    private static boolean https(String url){return url!=null&&url.startsWith("https://");}
    private JSONArray read()throws JSONException{return new JSONArray(context.getSharedPreferences("downloads",0).getString("items","[]"));}
    private void save(JSONArray entries) {
        if(!context.getSharedPreferences("downloads",0).edit().putString("items",entries.toString()).commit())throw new IllegalStateException("Could not save download changes");
    }
    private static Map<String,Object> jsonMap(JSONObject object)throws JSONException {
        Map<String,Object> map=new HashMap<>();Iterator<String> keys=object.keys();
        while(keys.hasNext()){String key=keys.next();Object value=object.get(key);map.put(key,value==JSONObject.NULL?null:value);}return map;
    }
    @Override public void close(){channel.setMethodCallHandler(null);worker.shutdown();}
}
