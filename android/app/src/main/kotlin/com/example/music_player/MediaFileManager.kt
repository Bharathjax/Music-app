package com.example.music_player

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.media.MediaScannerConnection
import io.flutter.plugin.common.MethodChannel

/**
 * File mutation and storage-access handling for media files.
 *
 * This class owns rename, delete, and MediaStore write-access flows.
 * Playback and read-only media-library queries intentionally remain
 * outside this class.
 */
class MediaFileManager(
    private val context: Context
) {

    companion object {
        const val MEDIA_WRITE_REQUEST_CODE = 1002
        const val MEDIA_DELETE_REQUEST_CODE = 1003
        const val MANAGE_ALL_FILES_REQUEST_CODE = 1004
    }

    private var mediaWritePermissionResult: MethodChannel.Result? = null
    private var mediaDeletePermissionResult: MethodChannel.Result? = null

    private var pendingRenameUri: Uri? = null
    private var pendingRenameName: String? = null
    private var pendingRenameResult: MethodChannel.Result? = null

    private var pendingDeleteUri: Uri? = null
    private var pendingDeleteResult: MethodChannel.Result? = null

    fun renameSong(
        activity: Activity,
        uriString: String,
        requestedName: String,
        result: MethodChannel.Result
    ) {
        val uri = try {
            Uri.parse(uriString)
        } catch (_: Exception) {
            result.error("INVALID_URI", "Invalid media URI.", null)
            return
        }

        val newName = buildDisplayName(uri, requestedName)

        // Android 11+ uses direct filesystem rename when All Files Access
        // has been granted. This preserves the existing ZArchiver-style
        // physical filename rename behavior.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                pendingRenameUri = uri
                pendingRenameName = newName
                pendingRenameResult = result

                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    )
                    activity.startActivityForResult(
                        intent,
                        MANAGE_ALL_FILES_REQUEST_CODE
                    )
                } catch (e: Exception) {
                    clearPendingRename()
                    result.error(
                        "MANAGE_STORAGE_ERROR",
                        e.message ?: "Unable to open storage access settings.",
                        null
                    )
                }
                return
            }

            performDirectFileRename(uri, newName, result)
            return
        }

        // Android 10 and below: use the legacy MediaStore update path.
        try {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, newName)
                put(MediaStore.Audio.Media.TITLE, titleFromDisplayName(newName))
            }
            val updated = context.contentResolver.update(uri, values, null, null)
            result.success(updated > 0)
        } catch (e: android.app.RecoverableSecurityException) {
            pendingRenameUri = uri
            pendingRenameName = newName
            pendingRenameResult = result
            activity.startIntentSenderForResult(
                e.userAction.actionIntent.intentSender,
                MEDIA_WRITE_REQUEST_CODE,
                null, 0, 0, 0
            )
        } catch (e: Exception) {
            result.error(
                "RENAME_FAILED",
                e.message ?: "Unable to rename song.",
                null
            )
        }
    }

    private fun performDirectFileRename(
        uri: Uri,
        newName: String,
        result: MethodChannel.Result
    ) {
        try {
            var oldPath: String? = null

            context.contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DATA),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val column = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                    if (column >= 0) {
                        oldPath = cursor.getString(column)
                    }
                }
            }

            if (oldPath.isNullOrBlank()) {
                result.error(
                    "PATH_NOT_FOUND",
                    "Could not determine the song file path.",
                    null
                )
                return
            }

            val oldFile = java.io.File(oldPath!!)
            if (!oldFile.exists()) {
                result.error(
                    "FILE_NOT_FOUND",
                    "The song file no longer exists on storage.",
                    null
                )
                return
            }

            val newFile = java.io.File(oldFile.parentFile, newName)

            if (newFile.absolutePath == oldFile.absolutePath) {
                result.success(true)
                return
            }

            if (newFile.exists()) {
                result.error(
                    "FILE_EXISTS",
                    "A file with that name already exists.",
                    null
                )
                return
            }

            if (!oldFile.renameTo(newFile)) {
                result.error(
                    "RENAME_FAILED",
                    "Android could not rename the file.",
                    null
                )
                return
            }

            // Keep MediaStore metadata synchronized with the physical file.
            try {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, newName)
                    put(MediaStore.Audio.Media.TITLE, titleFromDisplayName(newName))
                }
                context.contentResolver.update(uri, values, null, null)
            } catch (_: Exception) {
                // Physical rename already succeeded.
            }

            MediaScannerConnection.scanFile(
                context,
                arrayOf(newFile.absolutePath),
                null,
                null
            )

            result.success(true)
        } catch (e: SecurityException) {
            result.error(
                "STORAGE_PERMISSION_DENIED",
                e.message ?: "Storage access was not granted.",
                null
            )
        } catch (e: Exception) {
            result.error(
                "RENAME_FAILED",
                e.message ?: "Unable to rename song.",
                null
            )
        }
    }

    fun deleteSong(
        activity: Activity,
        uriString: String,
        result: MethodChannel.Result
    ) {
        val uri = try {
            Uri.parse(uriString)
        } catch (_: Exception) {
            result.error("INVALID_URI", "Invalid media URI.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val pendingIntent = MediaStore.createDeleteRequest(
                    context.contentResolver,
                    listOf(uri)
                )
                mediaDeletePermissionResult = result
                pendingDeleteUri = uri
                activity.startIntentSenderForResult(
                    pendingIntent.intentSender,
                    MEDIA_DELETE_REQUEST_CODE,
                    null, 0, 0, 0
                )
            } catch (e: Exception) {
                result.error(
                    "MEDIA_DELETE_REQUEST_ERROR",
                    e.message ?: "Unable to request delete access.",
                    null
                )
            }
            return
        }

        try {
            result.success(
                context.contentResolver.delete(uri, null, null) > 0
            )
        } catch (e: android.app.RecoverableSecurityException) {
            pendingDeleteUri = uri
            pendingDeleteResult = result
            activity.startIntentSenderForResult(
                e.userAction.actionIntent.intentSender,
                MEDIA_DELETE_REQUEST_CODE,
                null, 0, 0, 0
            )
        } catch (e: Exception) {
            result.error(
                "DELETE_FAILED",
                e.message ?: "Unable to delete song.",
                null
            )
        }
    }

    fun requestMediaWriteAccess(
        activity: Activity,
        uriString: String,
        result: MethodChannel.Result
    ) {
        val uri = try {
            Uri.parse(uriString)
        } catch (_: Exception) {
            result.error("INVALID_URI", "Invalid media URI.", null)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.success(true)
            return
        }

        try {
            val pendingIntent = MediaStore.createWriteRequest(
                context.contentResolver,
                listOf(uri)
            )

            mediaWritePermissionResult = result

            activity.startIntentSenderForResult(
                pendingIntent.intentSender,
                MEDIA_WRITE_REQUEST_CODE,
                null,
                0,
                0,
                0
            )
        } catch (e: Exception) {
            mediaWritePermissionResult = null
            result.error(
                "MEDIA_WRITE_REQUEST_ERROR",
                e.message ?: "Unable to request media write access.",
                null
            )
        }
    }

    fun handleActivityResult(
        requestCode: Int,
        resultCode: Int
    ): Boolean {
        when (requestCode) {
            MANAGE_ALL_FILES_REQUEST_CODE -> {
                val renameResult = pendingRenameResult
                val uri = pendingRenameUri
                val name = pendingRenameName

                if (renameResult != null && uri != null && name != null) {
                    if (Environment.isExternalStorageManager()) {
                        performDirectFileRename(uri, name, renameResult)
                    } else {
                        renameResult.error(
                            "STORAGE_PERMISSION_DENIED",
                            "All files access was not granted.",
                            null
                        )
                    }
                }

                clearPendingRename()
                return true
            }

            MEDIA_WRITE_REQUEST_CODE -> {
                val granted = resultCode == Activity.RESULT_OK
                val renameResult = pendingRenameResult

                if (renameResult != null) {
                    val success = granted && performPendingRename()
                    renameResult.success(success)
                    clearPendingRename()
                } else {
                    mediaWritePermissionResult?.success(granted)
                    mediaWritePermissionResult = null
                }
                return true
            }

            MEDIA_DELETE_REQUEST_CODE -> {
                val granted = resultCode == Activity.RESULT_OK
                val deleteResult = pendingDeleteResult

                if (deleteResult != null) {
                    val success = granted && performPendingDelete()
                    deleteResult.success(success)
                    pendingDeleteResult = null
                    pendingDeleteUri = null
                } else {
                    mediaDeletePermissionResult?.success(granted)
                    mediaDeletePermissionResult = null
                }
                return true
            }
        }

        return false
    }

    private fun performPendingRename(): Boolean {
        val uri = pendingRenameUri ?: return false
        val name = pendingRenameName ?: return false

        return try {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.Audio.Media.TITLE, titleFromDisplayName(name))
            }
            context.contentResolver.update(uri, values, null, null) > 0
        } catch (_: Exception) {
            false
        }
    }

    private fun performPendingDelete(): Boolean {
        val uri = pendingDeleteUri ?: return false
        return try {
            context.contentResolver.delete(uri, null, null) > 0
        } catch (_: Exception) {
            false
        }
    }

    private fun buildDisplayName(uri: Uri, requestedName: String): String {
        var currentName: String? = null
        context.contentResolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                currentName = cursor.getString(0)
            }
        }

        val clean = requestedName.trim()
        if (clean.contains('.')) return clean

        val current = currentName?.trim().orEmpty()
        val dot = current.lastIndexOf('.')
        val extension = if (dot > 0 && dot < current.length - 1) {
            current.substring(dot)
        } else {
            ""
        }

        return clean + extension
    }

    private fun titleFromDisplayName(displayName: String): String {
        val dot = displayName.lastIndexOf('.')
        return if (dot > 0) displayName.substring(0, dot) else displayName
    }

    fun clearPendingResults() {
        mediaWritePermissionResult = null
        mediaDeletePermissionResult = null
        clearPendingRename()
        pendingDeleteResult = null
        pendingDeleteUri = null
    }

    private fun clearPendingRename() {
        pendingRenameResult = null
        pendingRenameUri = null
        pendingRenameName = null
    }
}
