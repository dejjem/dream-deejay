# Flutter default rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# audio_service
-keep class com.ryanheise.audioservice.** { *; }

# just_audio
-keep class com.google.android.exoplayer2.** { *; }

# Retrofit / OkHttp
-keepattributes Signature
-keepattributes *Annotation*
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-dontwarn retrofit2.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }
-keep class com.dreamdeejay.app.data.models.** { *; }

# JSON serializable
-keep class **$$JsonObjectIteratorImpl { *; }
-keep class **$$JsonSerializable { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Flutter TTS
-keep class com.tundralabs.fluttertts.** { *; }

# Coil
-keep class coil.** { *; }

# Riverpod
-keep class ref.watch.** { *; }
-keep class ref.invoke.** { *; }