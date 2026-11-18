# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core (Flutter Deferred Components)
-dontwarn com.google.android.play.core.**

# Keep Firebase & Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.firebase.** { *; }

# R8 Bitmap & Optimization rules
-dontwarn org.webrtc.**
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

# General ProGuard safety
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.**
-keepclassmembers enum * { *; }
