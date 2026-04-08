# BUILD_STABILITY (§10): Protect Yandex SDK and Kotlin Parcelize from R8 shrinking.
-keep class kotlinx.parcelize.** { *; }
-keep class com.yandex.authsdk.** { *; }
# Parcelize is a compile-time annotation; allow R8 to proceed if the annotation class is not in runtime classpath.
-dontwarn kotlinx.parcelize.Parcelize

# Wear plugin references optional com.google.android.wearable.compat.* (may be absent on phone APK); R8 must not fail the build.
-dontwarn com.google.android.wearable.compat.**
-keep class com.google.android.wearable.compat.** { *; }
