# BUILD_STABILITY (§10): Protect Yandex SDK and Kotlin Parcelize from R8 shrinking.
-keep class kotlinx.parcelize.** { *; }
-keep class com.yandex.authsdk.** { *; }
# Parcelize is a compile-time annotation; allow R8 to proceed if the annotation class is not in runtime classpath.
-dontwarn kotlinx.parcelize.Parcelize
