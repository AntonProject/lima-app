# LIMA — R8/ProGuard keep rules for release builds.
# Conservative rules: keep what plugins reach via reflection / JNI.

# ── Flutter core ─────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ── WorkManager (background sync, isolate entrypoint via reflection) ─────────
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }

# ── sqflite (JNI / SQLite bindings) ──────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── connectivity_plus ────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── Keep annotations / generics / signatures used by reflection-based libs ───
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── Suppress warnings for optional / desugared deps ──────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
