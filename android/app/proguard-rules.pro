# SLF4J rules
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.LoggerFactory
-dontwarn org.slf4j.helpers.NOPLoggerFactory
-dontwarn org.slf4j.helpers.Util
-dontwarn org.slf4j.impl.StaticMDCBinder
-dontwarn org.slf4j.impl.StaticMarkerBinder

# Mapbox rules (often needed)
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**
