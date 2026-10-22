# Plugins Flutter appelés depuis Dart via JNI : R8 ne voit pas ces appels.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class dev.flutter.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**
