package com.example.counter

import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import android.util.Base64
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val PEOPLE_CONTACTS_REQUEST_CODE = 4812
    }

    private var pendingPeopleContactsResult: MethodChannel.Result? = null
    private var peopleContactsReadInProgress = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "counter/wear",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isWear" -> {
                    val isWatch =
                        packageManager.hasSystemFeature(PackageManager.FEATURE_WATCH)
                    result.success(isWatch)
                }

                "isRound" -> result.success(resources.configuration.isScreenRound)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "counter/context_awareness",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(ContextAwarenessBridge.status(this))
                "suggestPlaces" -> ContextAwarenessBridge.suggestPlaces(
                    this,
                    call.argument<Double>("latitude") ?: Double.NaN,
                    call.argument<Double>("longitude") ?: Double.NaN,
                    result,
                )
                "setHome" -> ContextAwarenessBridge.setHome(this, result)
                "enable" -> ContextAwarenessBridge.enable(
                    this, call.argument<String>("profileId") ?: "", result,
                )
                "disable" -> {
                    ContextAwarenessBridge.disable(this)
                    result.success(ContextAwarenessBridge.status(this))
                }
                "events" -> result.success(ContextAwarenessBridge.events(
                    this, call.argument<String>("profileId") ?: "",
                ))
                "acknowledge" -> {
                    ContextAwarenessBridge.acknowledge(
                        this, call.argument<String>("profileId") ?: "",
                        call.argument<String>("eventId") ?: "",
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "counter/people_contacts",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAndReadContacts" -> requestAndReadPeopleContacts(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestAndReadPeopleContacts(result: MethodChannel.Result) {
        if (peopleContactsReadInProgress || pendingPeopleContactsResult != null) {
            result.error("contacts_request_in_progress", "Contacts request is already active", null)
            return
        }
        if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            readPeopleContactsAsync(result)
            return
        }
        pendingPeopleContactsResult = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_CONTACTS),
            PEOPLE_CONTACTS_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PEOPLE_CONTACTS_REQUEST_CODE) return
        val result = pendingPeopleContactsResult ?: return
        pendingPeopleContactsResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error("permission_denied", "Contacts permission is required", null)
            return
        }
        readPeopleContactsAsync(result)
    }

    private fun readPeopleContactsAsync(result: MethodChannel.Result) {
        peopleContactsReadInProgress = true
        Thread {
            try {
                val rows = readPeopleContacts()
                runOnUiThread {
                    peopleContactsReadInProgress = false
                    result.success(rows)
                }
            } catch (error: Throwable) {
                runOnUiThread {
                    peopleContactsReadInProgress = false
                    result.error("contacts_read_failed", error.message, null)
                }
            }
        }.start()
    }

    private fun readPeopleContacts(): List<Map<String, Any?>> {
        // Read contact details in three bulk cursor queries, rather than
        // issuing three ContentResolver queries per contact. Prefer explicitly
        // marked primary values, then deterministic row order.
        val phones = readContactValues(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        val emails = readContactValues(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            ContactsContract.CommonDataKinds.Email.CONTACT_ID,
            ContactsContract.CommonDataKinds.Email.ADDRESS,
        )
        val birthdays = readContactValues(
            ContactsContract.Data.CONTENT_URI,
            ContactsContract.Data.CONTACT_ID,
            ContactsContract.CommonDataKinds.Event.START_DATE,
            ContactsContract.Data.MIMETYPE + " = ? AND " +
                ContactsContract.CommonDataKinds.Event.TYPE + " = ?",
            arrayOf(
                ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE,
                ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString(),
            ),
        )
        val out = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
            ContactsContract.Contacts.PHOTO_THUMBNAIL_URI,
        )
        contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            projection,
            null,
            null,
            ContactsContract.Contacts.DISPLAY_NAME_PRIMARY + " COLLATE LOCALIZED ASC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(
                ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
            )
            val photoIndex = cursor.getColumnIndexOrThrow(
                ContactsContract.Contacts.PHOTO_THUMBNAIL_URI,
            )
            while (cursor.moveToNext()) {
                val contactId = cursor.getString(idIndex) ?: continue
                val displayName = cursor.getString(nameIndex)?.trim().orEmpty()
                val photoUri = cursor.getString(photoIndex)?.trim().orEmpty()
                val phone = phones[contactId].orEmpty()
                val email = emails[contactId].orEmpty()
                val birthday = parseContactBirthday(birthdays[contactId].orEmpty())
                val avatar = photoDataUri(photoUri)
                out.add(
                    mapOf(
                        "external_id" to contactId,
                        "display_name" to displayName,
                        "primary_phone" to phone,
                        "primary_email" to email,
                        "birthday_month" to birthday?.first,
                        "birthday_day" to birthday?.second,
                        "birthday_year" to birthday?.third,
                        "avatar_data_uri" to avatar,
                        "raw_meta" to mapOf("platform" to "android"),
                    ),
                )
            }
        }
        return out
    }

    private fun readContactValues(
        uri: android.net.Uri,
        idColumn: String,
        valueColumn: String,
        selection: String? = null,
        selectionArgs: Array<String>? = null,
    ): Map<String, String> {
        val values = mutableMapOf<String, String>()
        contentResolver.query(
            uri,
            arrayOf(idColumn, valueColumn),
            selection,
            selectionArgs,
            idColumn + " ASC, " + ContactsContract.Data.IS_SUPER_PRIMARY +
                " DESC, " + ContactsContract.Data.IS_PRIMARY + " DESC, " +
                ContactsContract.Data._ID + " ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: continue
                val value = cursor.getString(1)?.trim().orEmpty()
                if (value.isNotEmpty() && !values.containsKey(id)) {
                    values[id] = value
                }
            }
        }
        return values
    }

    private fun parseContactBirthday(raw: String): Triple<Int, Int, Int?>? {
        val match = Regex("^(?:(\\d{4})-)?-?(\\d{1,2})-(\\d{1,2})$").find(raw)
            ?: return null
        val year = match.groupValues[1].toIntOrNull()
        val month = match.groupValues[2].toIntOrNull() ?: return null
        val day = match.groupValues[3].toIntOrNull() ?: return null
        if (month !in 1..12 || day !in 1..31) return null
        return Triple(month, day, year)
    }

    private fun photoDataUri(uriText: String): String {
        if (uriText.isBlank()) return ""
        return try {
            contentResolver.openInputStream(android.net.Uri.parse(uriText))?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isEmpty()) {
                    ""
                } else {
                    "data:image/jpeg;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP)
                }
            } ?: ""
        } catch (_: Throwable) {
            ""
        }
    }
}
