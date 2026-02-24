package com.example.airotrack

import android.util.Log
import com.mapbox.geojson.LineString
import com.mapbox.geojson.Point
import com.mapbox.maps.MapboxMap
import com.mapbox.maps.Style
import com.mapbox.maps.extension.style.layers.addLayer
import com.mapbox.maps.extension.style.layers.generated.lineLayer
import com.mapbox.maps.extension.style.layers.properties.generated.LineCap
import com.mapbox.maps.extension.style.layers.properties.generated.LineJoin
import com.mapbox.maps.extension.style.sources.addSource
import com.mapbox.maps.extension.style.sources.generated.geoJsonSource
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Mapbox Map Matching API (v5) + drawing on Mapbox map.
 *
 * - Sorts [LocationPoint] by timestamp
 * - Batches up to 100 coordinates per request
 * - Snaps GPS track to roads (driving profile), decodes geometry, draws on [MapboxMap]
 * - Handles API errors gracefully; on failure does not draw (caller can fall back to raw polyline)
 *
 * Requires: Mapbox Maps SDK, OkHttp, and a Mapbox access token with Map Matching scope.
 *
 * When using this API, do not draw the raw GPS polyline on the same map; this draws the
 * matched (snapped-to-road) route only.
 *
 * Usage example (e.g. from an Activity with a MapView):
 *   mapView.getMapboxMap().loadStyle(Style.STANDARD) { style ->
 *     MapboxMapMatching.drawMatchedRoute(
 *       mapboxMap = mapView.mapboxMap,
 *       accessToken = getString(R.string.mapbox_access_token),
 *       points = listOf(
 *         LocationPoint(52.0, 9.0, 0L),      // lat, lng, timestamp
 *         LocationPoint(52.01, 9.01, 1000L),
 *         ...
 *       ),
 *       onSuccess = { runOnUiThread { Toast.makeText(this, "Route drawn", LENGTH_SHORT).show() } },
 *       onError = { msg, _ -> runOnUiThread { Toast.makeText(this, msg, LENGTH_LONG).show() } }
 *     )
 *   }
 */
object MapboxMapMatching {

    private const val TAG = "MapboxMapMatching"

    /** Map Matching API base URL (driving profile). Max 100 points per request. */
    private const val MAP_MATCHING_BASE =
        "https://api.mapbox.com/matching/v5/mapbox/driving"

    /** Default source and layer IDs for the matched route (can be overridden). */
    const val DEFAULT_ROUTE_SOURCE_ID = "map-matched-route-source"
    const val DEFAULT_ROUTE_LAYER_ID = "map-matched-route-layer"

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    /**
     * Result of matching: either success with list of [Point] (lng, lat) or failure with message.
     */
    sealed class MatchResult {
        data class Success(val points: List<Point>) : MatchResult()
        data class Failure(val message: String, val cause: Throwable? = null) : MatchResult()
    }

    /**
     * Draws a road-matched route on the Mapbox map from a list of GPS points.
     *
     * - Sorts [points] by timestamp
     * - Filters invalid coordinates (0,0 and out-of-range)
     * - Batches into chunks of up to 100 coordinates, calls Map Matching API per chunk
     * - Decodes returned GeoJSON geometry and merges chunks
     * - Removes any existing route layer/source with the same IDs, then adds new source and line layer
     *
     * Call from the main/UI thread after the style is loaded (e.g. in [MapboxMap.getStyle] callback
     * or after [MapboxMap.loadStyle] has invoked its completion).
     *
     * @param mapboxMap The Mapbox map (style must be loaded).
     * @param accessToken Mapbox public access token (with Map Matching allowed).
     * @param points Ordered or unordered GPS points (will be sorted by timestamp).
     * @param sourceId ID for the GeoJSON source (default [DEFAULT_ROUTE_SOURCE_ID]).
     * @param layerId ID for the line layer (default [DEFAULT_ROUTE_LAYER_ID]).
     * @param lineColor Hex color for the line (e.g. "#3b82f6").
     * @param lineWidth Line width in pixels.
     * @param onSuccess Called when the matched route was drawn. May be on a background thread; post to main if updating UI.
     * @param onError Called when matching or drawing failed. May be on a background thread; post to main if showing a toast.
     */
    @JvmOverloads
    fun drawMatchedRoute(
        mapboxMap: MapboxMap,
        accessToken: String,
        points: List<LocationPoint>,
        sourceId: String = DEFAULT_ROUTE_SOURCE_ID,
        layerId: String = DEFAULT_ROUTE_LAYER_ID,
        lineColor: String = "#3b82f6",
        lineWidth: Double = 6.0,
        onSuccess: () -> Unit = {},
        onError: (String, Throwable?) -> Unit = { msg, _ -> Log.e(TAG, msg) }
    ) {
        if (accessToken.isBlank()) {
            onError("Mapbox access token is empty", null)
            return
        }

        val sorted = points
            .filter { isValid(it) }
            .sortedBy { it.timestamp }

        if (sorted.size < 2) {
            onError("Need at least 2 valid points (got ${sorted.size})", null)
            return
        }

        matchRoute(accessToken, sorted, onResult = { result ->
            when (result) {
                is MatchResult.Success -> {
                    if (result.points.size < 2) {
                        onError("Map Matching returned too few points", null)
                        return@matchRoute
                    }
                    drawLineOnMap(
                        mapboxMap = mapboxMap,
                        points = result.points,
                        sourceId = sourceId,
                        layerId = layerId,
                        lineColor = lineColor,
                        lineWidth = lineWidth,
                        onSuccess = onSuccess,
                        onError = onError
                    )
                }
                is MatchResult.Failure -> onError(result.message, result.cause)
            }
        })
    }

    /**
     * Runs Map Matching only (no drawing). Use when you want to get matched coordinates
     * and draw them yourself or send to Flutter.
     */
    fun matchRoute(
        accessToken: String,
        points: List<LocationPoint>,
        onResult: (MatchResult) -> Unit
    ) {
        val sorted = points.filter { isValid(it) }.sortedBy { it.timestamp }
        if (sorted.size < 2) {
            onResult(MatchResult.Failure("Need at least 2 valid points (got ${sorted.size})", null))
            return
        }

        val chunkSize = 100
        val allMatched = mutableListOf<Point>()
        var lastLng: Double? = null
        var lastLat: Double? = null

        for (start in sorted.indices step chunkSize) {
            val end = (start + chunkSize).coerceAtMost(sorted.size)
            val chunk = sorted.subList(start, end)
            val coords = chunk.joinToString(";") { "${it.longitude},${it.latitude}" }
            val radiuses = chunk.joinToString(";") { "30" } // 30m radius per point
            val url = "$MAP_MATCHING_BASE/$coords.json" +
                "?geometries=geojson" +
                "&overview=full" +
                "&tidy=true" +
                "&radiuses=$radiuses" +
                "&access_token=$accessToken"

            val request = Request.Builder().url(url).get().build()
            try {
                httpClient.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        val body = response.body?.string().orEmpty()
                        onResult(
                            MatchResult.Failure(
                                "Map Matching HTTP ${response.code}: $body",
                                null
                            )
                        )
                        return
                    }
                    val body = response.body?.string() ?: ""
                    val parsed = parseMatchResponse(body)
                    if (parsed.isEmpty()) {
                        onResult(
                            MatchResult.Failure(
                                "Map Matching returned no geometry (code or matchings missing)",
                                null
                            )
                        )
                        return
                    }
                    // Merge: drop first point of this chunk if it duplicates previous chunk end
                    val toAdd = mutableListOf<Point>()
                    for (p in parsed) {
                        val lng = p.longitude()
                        val lat = p.latitude()
                        if (lastLng != null && lastLat != null && lastLng == lng && lastLat == lat) continue
                        toAdd.add(p)
                        lastLng = lng
                        lastLat = lat
                    }
                    allMatched.addAll(toAdd)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Map Matching request failed", e)
                onResult(MatchResult.Failure("Map Matching failed: ${e.message}", e))
                return
            }
        }

        if (allMatched.size < 2) {
            onResult(MatchResult.Failure("Map Matching produced too few points", null))
            return
        }
        onResult(MatchResult.Success(allMatched))
    }

    private fun isValid(p: LocationPoint): Boolean {
        if (p.latitude == 0.0 && p.longitude == 0.0) return false
        if (p.latitude !in -90.0..90.0 || p.longitude !in -180.0..180.0) return false
        return true
    }

    /**
     * Parses Mapbox Map Matching response JSON. Returns list of [Point] (lng, lat).
     * Expects geometries=geojson so geometry.coordinates is array of [lng, lat].
     */
    private fun parseMatchResponse(jsonBody: String): List<Point> {
        val out = mutableListOf<Point>()
        try {
            val root = JSONObject(jsonBody)
            if (root.optString("code") != "Ok") return out
            val matchings = root.optJSONArray("matchings") ?: return out
            for (i in 0 until matchings.length()) {
                val m = matchings.optJSONObject(i) ?: continue
                val geometry = m.optJSONObject("geometry") ?: continue
                val coords = geometry.optJSONArray("coordinates") ?: continue
                for (j in 0 until coords.length()) {
                    val c = coords.optJSONArray(j) ?: continue
                    if (c.length() >= 2) {
                        val lng = c.optDouble(0, Double.NaN)
                        val lat = c.optDouble(1, Double.NaN)
                        if (!lat.isNaN() && !lng.isNaN()) out.add(Point.fromLngLat(lng, lat))
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Parse Map Matching response failed", e)
        }
        return out
    }

    /**
     * Draws a line on the map from a list of [Point] (e.g. from [matchRoute]).
     * Removes existing layer and source with the same IDs before adding.
     */
    private fun drawLineOnMap(
        mapboxMap: MapboxMap,
        points: List<Point>,
        sourceId: String,
        layerId: String,
        lineColor: String,
        lineWidth: Double,
        onSuccess: () -> Unit,
        onError: (String, Throwable?) -> Unit
    ) {
        mapboxMap.getStyle { style ->
            try {
                if (style.styleLayerExists(layerId)) style.removeStyleLayer(layerId)
                if (style.styleSourceExists(sourceId)) style.removeStyleSource(sourceId)
            } catch (_: Exception) { /* ignore if not present */ }

            try {
                val lineString = LineString.fromLngLats(points)
                val source = geoJsonSource(sourceId) {
                    geometry(lineString)
                }
                style.addSource(source)
                val layer = lineLayer(layerId, sourceId) {
                    lineCap(LineCap.ROUND)
                    lineJoin(LineJoin.ROUND)
                    lineColor(lineColor)
                    lineWidth(lineWidth)
                }
                style.addLayer(layer)
                onSuccess()
            } catch (e: Exception) {
                Log.e(TAG, "Draw route failed", e)
                onError("Draw route failed: ${e.message}", e)
            }
        }
    }
}
