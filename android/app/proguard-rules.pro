# ==============================================================================
# ParkLagbee Release Build ProGuard / R8 Rules
# Ensures Flutter, Supabase, shared_preferences, image_picker, and printing plugins work cleanly in release mode.
# ==============================================================================

# Flutter Engine & Plugin Interfaces
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# shared_preferences_android JNI Keep Rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Kotlin stdlib types referenced by JNI bindings
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep interface kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }
-keep interface kotlin.enums.EnumEntries { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }

# Supabase, Ktor & OkHttp Networking
-keep class io.ktor.** { *; }
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn io.ktor.**

# Image Picker & Printing/PDF Plugins
-keep class com.mr.flutter.plugin.imagepicker.** { *; }
-keep class net.nfet.printing.** { *; }

# Flutter deferred-component support is not used by this app.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
