# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Supabase
-keep class com.supabase.** { *; }
-dontwarn com.supabase.**

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# WebRTC
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Gson (used by Socket.IO)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# OkHttp (used by Supabase)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
