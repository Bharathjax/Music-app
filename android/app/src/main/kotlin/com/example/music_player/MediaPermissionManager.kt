package com.example.music_player

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Runtime permission handling for media libraries.
 *
 * Music permission is requested when the music library starts.
 * Video permission is intentionally available as a separate on-demand
 * operation for the future video library.
 */
class MediaPermissionManager {

    companion object {
        private const val AUDIO_REQUEST_CODE = 1001
        private const val VIDEO_REQUEST_CODE = 1005
    }

    private var audioResult: MethodChannel.Result? = null
    private var videoResult: MethodChannel.Result? = null

    fun hasAudioPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.READ_MEDIA_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            val readGranted = ContextCompat.checkSelfPermission(
                context, Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                val writeGranted = ContextCompat.checkSelfPermission(
                    context, Manifest.permission.WRITE_EXTERNAL_STORAGE
                ) == PackageManager.PERMISSION_GRANTED
                readGranted && writeGranted
            } else {
                readGranted
            }
        }
    }

    fun hasVideoPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.READ_MEDIA_VIDEO
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    fun requestAudioPermission(
        activity: Activity,
        result: MethodChannel.Result
    ) {
        if (hasAudioPermission(activity)) {
            result.success(true)
            return
        }

        audioResult = result
        val permissions = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                arrayOf(Manifest.permission.READ_MEDIA_AUDIO)
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.P ->
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                )
            else ->
                arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

        ActivityCompat.requestPermissions(
            activity,
            permissions,
            AUDIO_REQUEST_CODE
        )
    }

    fun requestVideoPermission(
        activity: Activity,
        result: MethodChannel.Result
    ) {
        if (hasVideoPermission(activity)) {
            result.success(true)
            return
        }

        videoResult = result
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_VIDEO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

        ActivityCompat.requestPermissions(
            activity,
            arrayOf(permission),
            VIDEO_REQUEST_CODE
        )
    }

    fun handlePermissionResult(
        requestCode: Int,
        grantResults: IntArray
    ): Boolean {
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        when (requestCode) {
            AUDIO_REQUEST_CODE -> {
                audioResult?.success(granted)
                audioResult = null
                return true
            }
            VIDEO_REQUEST_CODE -> {
                videoResult?.success(granted)
                videoResult = null
                return true
            }
        }

        return false
    }

    fun clearPendingResults() {
        audioResult = null
        videoResult = null
    }
}
