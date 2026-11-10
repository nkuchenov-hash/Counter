package com.example.counter

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.location.Geocoder
import android.location.Location
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
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
    private const val STILL_WORK = "lifeos-context-still-v1"
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
            "homeSet" to (store.contains("homeLat") && store.contains("homeLng")),
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
        // Permission removal must not crash the account/logout flow.
        try {
            LocationServices.getGeofencingClient(context).removeGeofences(homeIntent(context))
        } catch (_: Exception) { }
        try {
            ActivityRecognition.getClient(context).removeActivityUpdates(activityIntent(context))
        } catch (_: Exception) { }
    }

    fun disable(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(STILL_WORK)
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
    @Synchronized
    private fun emit(context: Context, kind: String, mode: String = "", atMillis: Long = System.currentTimeMillis()): String? {
        val store = prefs(context)
        if (!store.getBoolean("enabled", false)) return null
        val id = UUID.randomUUID().toString()
        val original = JSONArray(store.getString(EVENTS, "[]") ?: "[]")
        val event = JSONObject()
            .put("id", id)
            .put("kind", kind)
            .put("mode", mode)
            .put("at", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date(atMillis)))
        val remaining = JSONArray()
        val from = (original.length() - 63).coerceAtLeast(0)
        for (i in from until original.length()) remaining.put(original.get(i))
        remaining.put(event)
        store.edit().putString(EVENTS, remaining.toString()).apply()
        return id
    }

    // One coarse stop point, not a movement trail; only an opt-in local event.
    @Synchronized
    private fun attachStopLocation(context: Context, eventId: String, location: Location) {
        val age = System.currentTimeMillis() - location.time
        if (!location.hasAccuracy() || location.accuracy > 150f || age !in 0..600_000L) return
        val store = prefs(context)
        if (!store.getBoolean("enabled", false)) return
        val events = JSONArray(store.getString(EVENTS, "[]") ?: "[]")
        for (index in 0 until events.length()) {
            val item = events.optJSONObject(index) ?: continue
            if (item.optString("id") == eventId) {
                item.put("latitude", location.latitude)
                    .put("longitude", location.longitude)
                    .put("accuracy", location.accuracy)
                store.edit().putString(EVENTS, events.toString()).apply()
                break
            }
        }
    }

    private fun emitStop(context: Context, stillStartedMillis: Long) {
        val eventId = emit(context, "stationary_away", atMillis = stillStartedMillis) ?: return
        if (!has(context, Manifest.permission.ACCESS_FINE_LOCATION)) return
        try {
            LocationServices.getFusedLocationProviderClient(context).lastLocation
                .addOnSuccessListener { location ->
                    if (location != null) attachStopLocation(context, eventId, location)
                }
        } catch (_: SecurityException) { }
    }

    private fun scheduleStillCheck(context: Context) {
        val request = OneTimeWorkRequestBuilder<ContextStillWorker>()
            .setInitialDelay(4, TimeUnit.MINUTES).build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            STILL_WORK, ExistingWorkPolicy.REPLACE, request,
        )
    }

    private fun cancelStillCheck(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(STILL_WORK)
    }

    fun completeStillCheck(context: Context) {
        val store = prefs(context)
        val first = store.getLong("stillSince", 0L)
        if (!store.getBoolean("enabled", false) ||
            !store.getBoolean("away", false) ||
            store.getString("mode", "") != "still" ||
            store.getBoolean("stillSent", false) || first == 0L) return
        val elapsed = System.currentTimeMillis() - first
        if (elapsed < 4 * 60_000L) return
        store.edit().putBoolean("stillSent", true).apply()
        emitStop(context, first)
    }

    // Android Geocoder provides address candidates, not verified venue identity.
    fun suggestPlaces(context: Context, lat: Double, lng: Double, result: MethodChannel.Result) {
        if (!prefs(context).getBoolean("enabled", false) ||
            !lat.isFinite() || !lng.isFinite() ||
            lat !in -90.0..90.0 || lng !in -180.0..180.0) {
            result.success(emptyList<String>())
            return
        }
        Thread {
            val choices = try {
                if (!Geocoder.isPresent()) emptyList() else {
                    val address = Geocoder(context, Locale.getDefault())
                        .getFromLocation(lat, lng, 3).orEmpty()
                    address.flatMap { item ->
                        listOfNotNull(item.featureName, item.getAddressLine(0))
                    }.filter { it.isNotBlank() }.distinct().take(4)
                }
            } catch (_: Exception) { emptyList<String>() }
            Handler(Looper.getMainLooper()).post { result.success(choices) }
        }.start()
    }

    // Geofences are lost at reboot; restore only a prior explicit opt-in.
    fun restoreAfterBoot(context: Context) {
        val store = prefs(context)
        if (!store.getBoolean("enabled", false) || !hasRequiredPermissions(context)) return
        val lat = store.getString("homeLat", null)?.toDoubleOrNull() ?: return
        val lng = store.getString("homeLng", null)?.toDoubleOrNull() ?: return
        val geofence = Geofence.Builder()
            .setRequestId("home")
            .setCircularRegion(lat, lng, HOME_RADIUS_M)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .build()
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0).addGeofence(geofence).build()
        try {
            LocationServices.getGeofencingClient(context).addGeofences(request, homeIntent(context))
                .addOnSuccessListener {
                    store.edit().putBoolean("away", false)
                        .remove("mode").remove("stillSince").remove("stillSent").apply()
                }
            ActivityRecognition.getClient(context)
                .requestActivityUpdates(120_000L, activityIntent(context))
        } catch (_: Exception) { /* Show permission state on next app open. */ }
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
                            store.edit().putBoolean("away", true)
                                .remove("mode").remove("stillSince")
                                .remove("stillSent").apply()
                            emit(context, "left_home")
                        }
                    }
                    Geofence.GEOFENCE_TRANSITION_ENTER -> {
                        if (store.getBoolean("away", false)) {
                            store.edit().putBoolean("away", false)
                                .remove("mode").remove("stillSince").remove("stillSent").apply()
                            cancelStillCheck(context)
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
                        cancelStillCheck(context)
                        emit(context, "moving", mode)
                    }
                }
                if (mode == "still") {
                    val now = System.currentTimeMillis()
                    val first = store.getLong("stillSince", 0L)
                    if (first == 0L) {
                        store.edit().putLong("stillSince", now).apply()
                        scheduleStillCheck(context)
                    } else if (now - first >= 4 * 60_000L) {
                        completeStillCheck(context)
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

class ContextStillWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        ContextAwarenessBridge.completeStillCheck(applicationContext)
        return Result.success()
    }
}

class ContextAwarenessBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            ContextAwarenessBridge.restoreAfterBoot(context)
        }
    }
}
