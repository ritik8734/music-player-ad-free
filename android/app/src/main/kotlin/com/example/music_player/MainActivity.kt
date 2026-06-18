package com.example.music_player

import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.music_player/media_delete"
    private val PIN_CHANNEL = "com.example.music_player/media_pin"
    private val REQUEST_DELETE = 1001

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteSong" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path is required", null)
                            return@setMethodCallHandler
                        }
                        deleteSong(path, result)
                    }
                    else -> result.notImplemented()
                }
            }

        // New channel for pinning a song globally by updating MediaStore DATE_ADDED
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pinSongGlobally" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path is required", null)
                            return@setMethodCallHandler
                        }
                        pinSongGlobally(path, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pinSongGlobally(path: String, result: MethodChannel.Result) {
        try {
            // Find the content URI for this file path via MediaStore
            val contentUri = getContentUriForPath(path)
            if (contentUri == null) {
                result.error("NOT_FOUND", "File not found in MediaStore: $path", null)
                return
            }

            // Update DATE_ADDED to current time (in seconds since epoch)
            // This makes the song appear as "just added" in all music apps
            val nowSeconds = System.currentTimeMillis() / 1000
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DATE_ADDED, nowSeconds)
            }

            val rowsUpdated = contentResolver.update(contentUri, values, null, null)
            result.success(rowsUpdated > 0)
        } catch (e: Exception) {
            result.error("PIN_ERROR", e.message, null)
        }
    }

    private fun deleteSong(path: String, result: MethodChannel.Result) {
        try {
            // Find the content URI for this file path via MediaStore
            val contentUri = getContentUriForPath(path)
            if (contentUri == null) {
                result.error("NOT_FOUND", "File not found in MediaStore: $path", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ (API 30): Use createDeleteRequest for user confirmation
                val deleteRequest = MediaStore.createDeleteRequest(
                    contentResolver,
                    listOf(contentUri)
                )
                pendingResult = result
                startIntentSenderForResult(
                    deleteRequest.intentSender,
                    REQUEST_DELETE,
                    null, 0, 0, 0
                )
            } else {
                // Android 10 and below: Try direct deletion, handle RecoverableSecurityException
                try {
                    val rows = contentResolver.delete(contentUri, null, null)
                    result.success(rows > 0)
                } catch (e: RecoverableSecurityException) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        pendingResult = result
                        startIntentSenderForResult(
                            e.userAction.actionIntent.intentSender,
                            REQUEST_DELETE,
                            null, 0, 0, 0
                        )
                    } else {
                        result.error("PERMISSION", "Cannot delete file: ${e.message}", null)
                    }
                }
            }
        } catch (e: Exception) {
            result.error("DELETE_ERROR", e.message, null)
        }
    }

    private fun getContentUriForPath(path: String): Uri? {
        val projection = arrayOf(MediaStore.Audio.Media._ID)
        val selection = "${MediaStore.Audio.Media.DATA} = ?"
        val selectionArgs = arrayOf(path)

        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID))
                return ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
            }
        }
        return null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_DELETE) {
            val result = pendingResult
            pendingResult = null
            if (result != null) {
                result.success(resultCode == RESULT_OK)
            }
        }
    }
}
