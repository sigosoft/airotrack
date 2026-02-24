package com.example.airotrack

import kotlin.math.*

/**
 * GPS tracking point from API.
 */
data class LocationPoint(
    val latitude: Double,
    val longitude: Double,
    val timestamp: Long,
    val accuracy: Float? = null
)

/**
 * Clean point for polyline (use with Flutter google_maps_flutter or convert to LatLng in app).
 */
data class CleanLatLng(
    val latitude: Double,
    val longitude: Double
)

/**
 * Internal validated point.
 */
private data class ValidPoint(
    val latitude: Double,
    val longitude: Double,
    val timestamp: Long
)

/**
 * Cleans GPS path before drawing polyline. Reduces backward jumps and zig-zag from drift.
 *
 * 1. Sort by timestamp ascending
 * 2. Remove duplicate timestamps
 * 3. Remove invalid coordinates (0.0, 0.0)
 * 4. Remove low accuracy points (if accuracy > 30 m, ignore)
 * 5. Distance between consecutive points: Haversine (meters)
 * 6. Time difference: seconds
 * 7. Speed = distance / time (km/h)
 * 8. If speed > 120 km/h → ignore point (unrealistic spike)
 * 9. If distance < 5 m → ignore point (jitter)
 * 10. Return clean List<CleanLatLng> (convert to LatLng in Dart or native map when drawing)
 */
object PolylineHelper {

    private const val EARTH_RADIUS_METERS = 6_371_000.0

    /** Ignore point if accuracy (meters) is worse than this. Null accuracy is kept. */
    private const val MAX_ACCURACY_METERS = 30f

    /** Ignore point if implied speed > this (km/h). */
    private const val MAX_SPEED_KMH = 120.0

    /** Ignore point if distance from previous < this (m) — jitter. */
    private const val MIN_DISTANCE_METERS = 5.0

    /**
     * Haversine distance between two points in meters.
     */
    fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = (lat2 - lat1) * PI / 180
        val dLon = (lon2 - lon1) * PI / 180
        val rLat1 = lat1 * PI / 180
        val rLat2 = lat2 * PI / 180
        val a = sin(dLat / 2).pow(2) +
                cos(rLat1) * cos(rLat2) * sin(dLon / 2).pow(2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }

    /**
     * Cleans path: sort, dedupe, filter invalid/accuracy, then remove jitter and speed spikes.
     *
     * @param rawPoints GPS points from API
     * @return Clean list for polyline (use with Flutter GoogleMap Polyline or convert to platform LatLng)
     */
    fun processForPolyline(rawPoints: List<LocationPoint>): List<CleanLatLng> {
        // 1–4: Valid only (no 0,0; accuracy <= 30 m or null; valid range)
        val valid = rawPoints.mapNotNull { p ->
            if (p.latitude == 0.0 && p.longitude == 0.0) return@mapNotNull null
            if (p.latitude !in -90.0..90.0 || p.longitude !in -180.0..180.0) return@mapNotNull null
            if (p.accuracy != null && p.accuracy > MAX_ACCURACY_METERS) return@mapNotNull null
            ValidPoint(p.latitude, p.longitude, p.timestamp)
        }

        if (valid.size <= 1) return valid.map { CleanLatLng(it.latitude, it.longitude) }

        // 1. Sort by timestamp ascending
        val sorted = valid.sortedBy { it.timestamp }

        // 2. Remove duplicate timestamps (keep first)
        val distinct = mutableListOf<ValidPoint>()
        val seen = mutableSetOf<Long>()
        for (p in sorted) {
            if (seen.add(p.timestamp)) distinct.add(p)
        }

        if (distinct.size <= 1) return distinct.map { CleanLatLng(it.latitude, it.longitude) }

        // 5–9: One pass — Haversine distance, time diff, speed; drop jitter and spikes
        val result = mutableListOf(distinct.first())
        for (i in 1 until distinct.size) {
            val prev = result.last()
            val curr = distinct[i]
            // 5. Distance (meters) — Haversine
            val distM = distanceMeters(prev.latitude, prev.longitude, curr.latitude, curr.longitude)
            // 6. Time difference (seconds)
            val timeSeconds = (curr.timestamp - prev.timestamp) / 1000.0

            // 9. Jitter: distance < 5 m → ignore
            if (distM < MIN_DISTANCE_METERS) continue

            // 7–8. Speed = distance / time (km/h). If time is 0, treat speed as 0 (keep point).
            val speedKmh = if (timeSeconds > 0) {
                (distM / 1000.0) / (timeSeconds / 3600.0)
            } else 0.0
            if (speedKmh > MAX_SPEED_KMH) continue

            result.add(curr)
        }

        // 10. Return clean list
        return result.map { CleanLatLng(it.latitude, it.longitude) }
    }
}
