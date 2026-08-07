# R8 is enabled for release builds. These keeps cover the libraries that break
# under shrinking, which is the usual reason a release APK fails where the
# debug build worked.

# Flutter embedding.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# sqflite.
-keep class com.tekartik.sqflite.** { *; }

# flutter_secure_storage relies on the AndroidX security library.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# local_auth / BiometricPrompt.
-keep class androidx.biometric.** { *; }

# flutter_local_notifications keeps its scheduled-notification model classes
# by reflection through Gson.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# The R8 full mode in AGP 8 warns about these optional Play Core classes that
# Flutter's deferred-components support references but this app does not use.
-dontwarn com.google.android.play.core.**

# Keep line numbers so crash reports from release builds stay readable, while
# still obfuscating names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
