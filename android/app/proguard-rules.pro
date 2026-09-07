# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep annotation
-keepattributes *Annotation*

# Cloud Functions
-keep class com.kahkenshaney.amongapp.** { *; }

# Keep Android resource IDs (prevents "Invalid ID 0x00000001" from
# stale native resource references after Firebase/plugin version bumps).
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Play Core classes referenced by Flutter's optional deferred-components engine
# (PlayStoreDeferredComponentManager / FlutterPlayStoreSplitApplication). This app
# uses no dynamic features, so these classes are never touched at runtime. The
# monolithic com.google.android.play:core artifact conflicts with core-common
# (pulled by firebase-auth via play-integrity), and the modular split artifacts
# are not on Google Maven, so R8 is told not to resolve them. This matches the
# keep rules Android generates in missing_rules.txt.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
