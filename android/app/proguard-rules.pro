# Regras ProGuard/R8 para release
# Mantém classes do Firebase e flutter_local_notifications
-keep class com.google.firebase.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.dexterous.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.play.core.**

# Tasks/Schedulers usados pelo flutter_local_notifications
-keep class androidx.work.** { *; }
-keep class androidx.lifecycle.DefaultLifecycleObserver

# Gson TypeToken - necessario para flutter_local_notifications com R8
-keepattributes Signature
-keepattributes *Annotation*
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
