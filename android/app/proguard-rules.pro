# Flutter's engine JNI and generated plugin registration use stable class names.
# Optional Play Store deferred delivery is not used by this self-contained app.
-keep class !io.flutter.embedding.android.FlutterPlayStoreSplitApplication,!io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager**,io.flutter.** { *; }

# PipePipe resolves localized timestamp parsers by class name and getInstance().
-keep class org.schabi.newpipe.extractor.timeago.patterns.** { *; }

# Wire discovers generated adapters/fields reflectively, including filter models.
-keep class ** extends com.squareup.wire.Message { *; }
-keep class ** implements com.squareup.wire.WireEnum { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
