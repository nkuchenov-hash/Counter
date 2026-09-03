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
            "counter/people_contacts",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readContacts" -> {
                    if (
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_CONTACTS,
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.error("permission_denied", "Contacts permission is required", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val rows = readPeopleContacts()
                            runOnUiThread { result.success(rows) }
                        } catch (error: Throwable) {
                            runOnUiThread {
                                result.error("contacts_read_failed", error.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readPeopleContacts(): List<Map<String, Any?>> {
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
                val phone = firstContactValue(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI.toString(),
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                    contactId,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                )
                val email = firstContactValue(
                    ContactsContract.CommonDataKinds.Email.CONTENT_URI.toString(),
                    ContactsContract.CommonDataKinds.Email.CONTACT_ID,
                    contactId,
                    ContactsContract.CommonDataKinds.Email.ADDRESS,
                )
                val birthday = birthdayForContact(contactId)
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

    private fun firstContactValue(
        uriText: String,
        idColumn: String,
        contactId: String,
        valueColumn: String,
    ): String {
        val uri = android.net.Uri.parse(uriText)
        contentResolver.query(
            uri,
            arrayOf(valueColumn),
            "$idColumn = ?",
            arrayOf(contactId),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)?.trim().orEmpty()
            }
        }
        return ""
    }

    private fun birthdayForContact(contactId: String): Triple<Int, Int, Int?>? {
        contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Event.START_DATE),
            ContactsContract.Data.CONTACT_ID + " = ? AND " +
                ContactsContract.Data.MIMETYPE + " = ? AND " +
                ContactsContract.CommonDataKinds.Event.TYPE + " = ?",
            arrayOf(
                contactId,
                ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE,
                ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString(),
            ),
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            val raw = cursor.getString(0)?.trim().orEmpty()
            val match = Regex("^(?:(\\d{4})-)?-?(\\d{1,2})-(\\d{1,2})$").find(raw)
                ?: return null
            val year = match.groupValues[1].toIntOrNull()
            val month = match.groupValues[2].toIntOrNull() ?: return null
            val day = match.groupValues[3].toIntOrNull() ?: return null
            if (month !in 1..12 || day !in 1..31) return null
            return Triple(month, day, year)
        }
        return null
    }

    private fun photoDataUri(uriText: String): String {
        if (uriText.isBlank()) return ""
        return try {
            contentResolver.openInputStream(android.net.Uri.parse(uriText))?.use { stream ->
                val bytes = stream.readBytes()
                if (bytes.isEmpty()) "" else
                    "data:image/jpeg;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP)
            } ?: ""
        } catch (_: Throwable) {
            ""
        }
    }
}
