package com.example.counter

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * Opt-in, event-driven Android context capture. Geofence + Activity Recognition
 * are owned by Android, not a Flutter timer. No raw movement trail is persisted
 * or sent to PocketBase. Only discrete inferred events enter the local queue.
 */
internal object ContextAwarenessBridge {
    private const val PREFS = "lifeos_context_awareness_v1"
    private const val EVENTS = "events"
    private const val GEOFENCE_ACTION = "com.example.counter.CONTEXT_HOME_GEOFENCE"
    private const val ACTIVITY_ACTION = "com.example.counter.CONTEXT_ACTIVITY"
    private const val HOME_RADIUS_M = 175f

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun homeIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context, 2210,
            Intent(context, ContextAwarenessReceiver::class.java).setAction(GEOFENCE_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    private fun activityIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context, 2211,
            Intent(context, ContextAwarenessReceiver::class.java).setAction(ACTIVITY_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    private fun has(context: Context, permission: String) =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    private fun hasRequiredPermissions(context: Context): Boolean =
        has(context, Manifest.permission.ACCESS_FINE_LOCATION) &&
            (Build.VERSION.SDK_INT < 29 ||
                has(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)) &&
            (Build.VERSION.SDK_INT < 29 ||
                has(context, Manifest.permission.ACTIVITY_RECOGNITION))

    fun status(context: Context): Map<String, Any> {
        val store = prefs(context)
        return mapOf(
            "enabled" to store.getBoolean("enabled", false),
            "homeSet" to store.contains("homeLat") && store.contains("homeLng"),
            "hasFineLocation" to has(context, Manifest.permission.ACCESS_FINE_LOCATION),
            "hasBackgroundLocation" to (Build.VERSION.SDK_INT < 29 ||
                has(context, Manifest.permission.ACCESS_BACKGROUND_LOCATION)),
            "hasActivityRecognition" to (Build.VERSION.SDK_INT < 29 ||
                has(context, Manifest.permission.ACTIVITY_RECOGNITION)),
        )
    }

    fun setHome(context: Context, result: MethodChannel.Result) {
        if (!has(context, Manifest.permission.ACCESS_FINE_LOCATION)) {
            result.error("permission", "Precise location permission is required", null)
            return
        }
        if (prefs(context).getBoolean("enabled", false)) {
            result.error("active", "Disable tracking before changing home", null)
            return
        }
        try {
            LocationServices.getFusedLocationProviderClient(context)
                .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                .addOnSuccessListener { location ->
                    if (location == null || !location.hasAccuracy() || location.accuracy > 100f) {
                        result.error("accuracy", "Cannot get an accurate current position; retry outside", null)
                        return@addOnSuccessListener
                    }
                    prefs(context).edit()
                        .putString("homeLat", location.latitude.toString())
                        .putString("homeLng", location.longitude.toString())
                        .apply()
                    result.success(status(context))
                }
                .addOnFailureListener { error ->
                    result.error("location", error.message ?: "Location unavailable", null)
                }
        } catch (error: SecurityException) {
            result.error("permission", "Location permission was revoked", null)
        }
    }

    fun enable(context: Context, profileId: String, result: MethodChannel.Result) {
        if (profileId.isBlank()) {
            result.error("auth", "Sign in before enabling tracking", null)
            return
        }
        val store = prefs(context)
        val lat = store.getString("homeLat", null)?.toDoubleOrNull()
        val lng = store.getString("homeLng", null)?.toDoubleOrNull()
        if (lat == null || lng == null) {
            result.error("home", "Save your home location first", null)
            return
        }
        if (!hasRequiredPermissions(context)) {
            result.error("permission", "Precise, all-the-time location and activity recognition are required", null)
            return
        }
        if (store.getBoolean("enabled", false)) {
            val oldOwner = store.getString("owner", null)
            if (oldOwner != profileId) {
                result.error("owner", "Disable tracking before switching accounts", null)
            } else {
                result.success(status(context))
            }
            return
        }
        val home = Geofence.Builder()
            .setRequestId("home")
            .setCircularRegion(lat, lng, HOME_RADIUS_M)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .build()
        val request = GeofencingRequest.Builder()
            // An initial trigger is not a real transition, so never manufacture a departure.
            .setInitialTrigger(0)
            .addGeofence(home)
            .build()
        try {
            val geo = LocationServices.getGeofencingClient(context)
                .addGeofences(request, homeIntent(context))
            val motion = ActivityRecognition.getClient(context)
                .requestActivityUpdates(120_000L, activityIntent(context))
            Tasks.whenAll(geo, motion)
                .addOnSuccessListener {
                    store.edit()
                        .putString("owner", profileId)
                        .putBoolean("enabled", true)
                        .putBoolean("away", false)
                        .remove("stillSince")
                        .remove("stillSent")
                        .apply()
                    result.success(status(context))
                }
                .addOnFailureListener { error ->
                    unregister(context)
                    result.error("registration", error.message ?: "Sensor registration failed", null)
                }
        } catch (error: Exception) {
            unregister(context)
            result.error("registration", error.message ?: "Sensor registration failed", null)
        }
    }

    private fun unregister(context: Context) {
        LocationServices.getGeofencingClient(context).removeGeofences(homeIntent(context))
        ActivityRecognition.getClient(context).removeActivityUpdates(activityIntent(context))
    }

    fun disable(context: Context) {
        // Disable first so racing broadcasts cannot append more events.
        prefs(context).edit()
            .putBoolean("enabled", false)
            .remove("owner")
            .remove("away")
            .remove("mode")
            .remove("stillSince")
            .remove("stillSent")
            .remove(EVENTS)
            .apply()
        unregister(context)
    }

    @Synchronized
    fun events(context: Context, profileId: String): String {
        val store = prefs(context)
        return if (store.getString("owner", null) == profileId &&
            store.getBoolean("enabled", false)) {
            store.getString(EVENTS, "[]") ?: "[]"
        } else "[]"
    }

    @Synchronized
    fun acknowledge(context: Context, profileId: String, eventId: String) {
        val store = prefs(context)
        if (store.getString("owner", null) != profileId) return
        val original = JSONArray(store.getString(EVENTS, "[]") ?: "[]")
        val remaining = JSONArray()
        for (i in 0 until original.length()) {
            val obj = original.optJSONObject(i) ?: continue
            if (obj.optString("id") != eventId) remaining.put(obj)
        }
        store.edit().putString(EVENTS, remaining.toString()).apply()
    }

    @Synchronized
    private fun emit(context: Context, kind: String, mode: String = "") {
        val store = prefs(context)
        if (!store.getBoolean("enabled", false)) return
        val original = JSONArray(store.getString(EVENTS, "[]") ?: "[]")
        val event = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("kind", kind)
            .put("mode", mode)
            .put("at", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date()))
        val remaining = JSONArray()
        val from = (original.length() - 63).coerceAtLeast(0)
        for (i in from until original.length()) remaining.put(original.get(i))
        remaining.put(event)
        store.edit().putString(EVENTS, remaining.toString()).apply()
    }

    fun receive(context: Context, intent: Intent) {
        val store = prefs(context)
        if (!store.getBoolean("enabled", false)) return
        when (intent.action) {
            GEOFENCE_ACTION -> {
                val event = GeofencingEvent.fromIntent(intent) ?: return
                if (event.hasError()) return
                when (event.geofenceTransition) {
                    Geofence.GEOFENCE_TRANSITION_EXIT -> {
                        if (!store.getBoolean("away", false)) {
                            store.edit().putBoolean("away", true).remove("stillSince").apply()
                            emit(context, "left_home")
                        }
                    }
                    Geofence.GEOFENCE_TRANSITION_ENTER -> {
                        if (store.getBoolean("away", false)) {
                            store.edit().putBoolean("away", false)
                                .remove("stillSince").remove("stillSent").apply()
                            emit(context, "arrived_home")
                        }
                    }
                }
            }
            ACTIVITY_ACTION -> {
                if (!store.getBoolean("away", false)) return
                val activity = ActivityRecognitionResult.extractResult(intent) ?: return
                val probable = activity.probableActivities.maxByOrNull { it.confidence } ?: return
                if (probable.confidence < 70) return
                val mode = when (probable.type) {
                    DetectedActivity.IN_VEHICLE -> "vehicle"
                    DetectedActivity.ON_BICYCLE -> "bicycle"
                    DetectedActivity.WALKING, DetectedActivity.ON_FOOT,
                    DetectedActivity.RUNNING -> "walking"
                    DetectedActivity.STILL -> "still"
                    else -> return
                }
                val previous = store.getString("mode", "")
                if (mode != previous) {
                    store.edit().putString("mode", mode).apply()
                    if (mode != "still") {
                        store.edit().remove("stillSince").remove("stillSent").apply()
                        emit(context, "moving", mode)
                    }
                }
                if (mode == "still") {
                    val now = System.currentTimeMillis()
                    val first = store.getLong("stillSince", 0L)
                    if (first == 0L) {
                        store.edit().putLong("stillSince", now).apply()
                    } else if (now - first >= 4 * 60_000L &&
                        !store.getBoolean("stillSent", false)) {
                        store.edit().putBoolean("stillSent", true).apply()
                        emit(context, "stationary_away")
                    }
                }
            }
        }
    }
}

class ContextAwarenessReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ContextAwarenessBridge.receive(context, intent)
    }
}
