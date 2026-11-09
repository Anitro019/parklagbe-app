# shared_preferences_android 2.5.x calls its Kotlin API from Dart through JNI (package:jni).
# R8 cannot see those calls, so it strips/renames the classes and the release build fails with
# NoSuchMethodError / ClassNotFoundException (Supabase then fails to initialize).
# Everything below is looked up BY NAME from Dart and must keep its real name.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Kotlin stdlib types referenced by name from package:jni and the generated bindings.
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep interface kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }
-keep interface kotlin.enums.EnumEntries { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }
