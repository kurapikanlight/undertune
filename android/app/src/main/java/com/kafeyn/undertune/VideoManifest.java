package com.kafeyn.undertune;

import org.schabi.newpipe.extractor.MediaFormat;
import org.schabi.newpipe.extractor.stream.*;
import org.schabi.newpipe.extractor.services.youtube.dashmanifestcreators.YoutubeProgressiveDashManifestCreator;
import java.io.*;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.*;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.*;
import org.xml.sax.InputSource;

/** Combine upstream's audio/video DASH representations for the Flutter video plugin. */
final class VideoManifest {
    static String create(StreamInfo info) throws Exception {
        VideoStream video = null;
        for (VideoStream candidate : info.getVideoOnlyStreams()) {
            if (!candidate.isUrl() || candidate.getDeliveryMethod()==DeliveryMethod.SABR
                    || candidate.getFormat()!=MediaFormat.MPEG_4 || candidate.getItagItem()==null) continue;
            String codec = candidate.getCodec();
            if (codec != null && !codec.startsWith("avc")) continue;
            if (video == null || candidate.getResolution().startsWith("720")) video = candidate;
            if (candidate.getResolution().startsWith("720")) break;
        }
        AudioStream audio = null;
        for (AudioStream candidate : info.getAudioStreams()) {
            if (candidate.isUrl() && candidate.getDeliveryMethod()!=DeliveryMethod.SABR
                    && candidate.getFormat()==MediaFormat.M4A && candidate.getItagItem()!=null) {audio=candidate;break;}
        }
        if (video==null || audio==null) return null;
        String videoXml=YoutubeProgressiveDashManifestCreator.fromProgressiveStreamingUrl(video.getContent(),video.getItagItem(),info.getDuration());
        String audioXml=YoutubeProgressiveDashManifestCreator.fromProgressiveStreamingUrl(audio.getContent(),audio.getItagItem(),info.getDuration());
        var factory=DocumentBuilderFactory.newInstance();
        factory.setExpandEntityReferences(false);
        var builder=factory.newDocumentBuilder();
        Document doc=builder.parse(new InputSource(new StringReader(videoXml)));
        Document audioDoc=builder.parse(new InputSource(new StringReader(audioXml)));
        Node adaptation=doc.importNode(audioDoc.getElementsByTagName("AdaptationSet").item(0),true);
        ((Element)adaptation).setAttribute("id","1");
        ((Element)doc.getElementsByTagName("AdaptationSet").item(0)).setAttribute("id","0");
        doc.getElementsByTagName("Period").item(0).appendChild(adaptation);
        StringWriter output=new StringWriter();
        TransformerFactory.newInstance().newTransformer().transform(new DOMSource(doc),new StreamResult(output));
        return output.toString();
    }
}
