package com.kafeyn.undertune;

import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;

/** Copies encoded H.264/AAC samples into one offline MP4; no quality-reducing transcode. */
final class VideoDownloadMuxer {
    static void merge(String videoPath, String audioPath, String outputPath) throws IOException {
        File temporary = new File(outputPath + ".assembling");
        MediaExtractor video = new MediaExtractor(), audio = new MediaExtractor();
        MediaMuxer muxer = null;
        boolean finished = false;
        try {
            video.setDataSource(videoPath); audio.setDataSource(audioPath);
            MediaFormat videoFormat = select(video,"video/avc");
            MediaFormat audioFormat = select(audio,"audio/mp4a-latm");
            muxer = new MediaMuxer(temporary.getAbsolutePath(),MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            int videoTrack = muxer.addTrack(videoFormat), audioTrack = muxer.addTrack(audioFormat);
            if (videoFormat.containsKey(MediaFormat.KEY_ROTATION)) muxer.setOrientationHint(videoFormat.getInteger(MediaFormat.KEY_ROTATION));
            int capacity = 8 * 1024 * 1024;
            if (videoFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) capacity = Math.max(capacity,videoFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE));
            ByteBuffer buffer = ByteBuffer.allocateDirect(capacity);
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            muxer.start();
            long videoSamples = 0, audioSamples = 0;
            while (video.getSampleTime() >= 0 || audio.getSampleTime() >= 0) {
                boolean useVideo = video.getSampleTime() >= 0 && (audio.getSampleTime() < 0 || video.getSampleTime() <= audio.getSampleTime());
                MediaExtractor source = useVideo ? video : audio;
                buffer.clear();
                int size = source.readSampleData(buffer,0);
                if (size < 0) throw new IOException("Could not read downloaded media");
                info.set(0,size,source.getSampleTime(),source.getSampleFlags() & MediaExtractor.SAMPLE_FLAG_SYNC);
                muxer.writeSampleData(useVideo ? videoTrack : audioTrack,buffer,info);
                if (useVideo) videoSamples++; else audioSamples++;
                source.advance();
            }
            if (videoSamples == 0 || audioSamples == 0) throw new IOException("Downloaded video or audio is empty");
            muxer.stop();muxer.release();muxer = null;
            if (!temporary.renameTo(new File(outputPath))) throw new IOException("Could not finalize video download");
            finished = true;
        } finally {
            if (muxer != null) { try { muxer.release(); } catch (Exception ignored) {} }
            video.release();audio.release();
            if (!finished) temporary.delete();
        }
    }
    private static MediaFormat select(MediaExtractor extractor,String mime) throws IOException {
        for (int i=0;i<extractor.getTrackCount();i++) {
            MediaFormat format = extractor.getTrackFormat(i);
            if (mime.equals(format.getString(MediaFormat.KEY_MIME))) { extractor.selectTrack(i);return format; }
        }
        throw new IOException("No compatible " + mime + " track in download");
    }
}
