# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mobile Scanner / ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.odml.** { *; }
-keepclassmembers class * implements com.google.android.gms.internal.mlkit_vision_barcode.** { *; }

# Prevent shrinking of barcode scanning models
-keep,allowobfuscation,allowshrinking class com.google.android.gms.internal.mlkit_vision_barcode.**
