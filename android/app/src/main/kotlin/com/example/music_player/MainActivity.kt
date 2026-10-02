package com.example.music_player

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {

    private val CHANNEL =
        "music_player/device_music"

    private val mediaPermissionManager =
        MediaPermissionManager()

    private val mediaLibraryManager by lazy {
        MediaLibraryManager(this)
    }

    private val mediaFileManager by lazy {
        MediaFileManager(this)
    }

    private val SONG_EVENTS_CHANNEL =
        "music_player/song_events"

    /*
     * Flutter listens to this EventChannel.
     *
     * When the Android MediaPlayer reaches the actual
     * end of a song, we send:
     *
     *     "songCompleted"
     *
     * to Flutter.
     */
    private var completionEventSink:
        EventChannel.EventSink? = null

    private val serviceEventReceiver =
        object : android.content.BroadcastReceiver() {
            override fun onReceive(
                context: android.content.Context?,
                intent: Intent?
            ) {
                val event =
                    intent?.getStringExtra(
                        MusicPlaybackService.EXTRA_EVENT
                    )
                if (!event.isNullOrEmpty()) {
                    completionEventSink?.success(event)
                }
            }
        }


    // =============================================================
    // FLUTTER METHOD CHANNEL
    // =============================================================

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {

        super.configureFlutterEngine(
            flutterEngine
        )


        // =========================================================
        // METHOD CHANNEL
        // =========================================================

        MethodChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {


                // =================================================
                // GET SONG ARTWORK
                // =================================================

                "getArtwork" -> {

                    val uriString =
                        call.argument<String>("uri")

                    if (uriString.isNullOrEmpty()) {

                        result.success(null)

                        return@setMethodCallHandler
                    }

                    result.success(
                        mediaLibraryManager.getArtwork(uriString)
                    )
                }



                "renameSong" -> {
                    val uriString = call.argument<String>("uri")
                    val newName = call.argument<String>("newName")
                    if (uriString.isNullOrBlank() || newName.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "Song URI and new name are required.", null)
                        return@setMethodCallHandler
                    }
                    mediaFileManager.renameSong(
                        this@MainActivity,
                        uriString,
                        newName.trim(),
                        result
                    )
                }

                "deleteSong" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString.isNullOrBlank()) {
                        result.error("INVALID_URI", "Song URI is missing.", null)
                        return@setMethodCallHandler
                    }
                    mediaFileManager.deleteSong(
                        this@MainActivity,
                        uriString,
                        result
                    )
                }

                // =================================================
                // REQUEST MEDIA WRITE ACCESS
                // =================================================

                "requestMediaWriteAccess" -> {

                    val uriString =
                        call.argument<String>("uri")

                    if (uriString.isNullOrEmpty()) {

                        result.error(
                            "INVALID_URI",
                            "Media URI is missing.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    mediaFileManager.requestMediaWriteAccess(
                        this@MainActivity,
                        uriString,
                        result
                    )
                }


                // =================================================
                // MUSIC PERMISSION
                // =================================================

                "requestMusicPermission" -> {
                    mediaPermissionManager.requestAudioPermission(
                        this@MainActivity,
                        result
                    )
                }

                // Future video library: request only when video access is needed.
                "requestVideoPermission" -> {
                    mediaPermissionManager.requestVideoPermission(
                        this@MainActivity,
                        result
                    )
                }


                // =================================================
                // GET DEVICE SONGS
                // =================================================

                "getDeviceSongs" -> {
                    if (mediaPermissionManager.hasAudioPermission(this@MainActivity)) {
                        result.success(mediaLibraryManager.getDeviceSongs())
                    } else {
                        result.error(
                            "PERMISSION_DENIED",
                            "Music permission has not been granted.",
                            null
                        )
                    }
                }


                // =================================================
                // PLAY SONG
                // =================================================

                "playSong" -> {

                    val uriString =
                        call.argument<String>("uri")

                    if (uriString.isNullOrEmpty()) {

                        result.error(
                            "INVALID_URI",
                            "Song URI is missing.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    playSong(
                        uriString,
                        call.argument<String>("title") ?: "Music",
                        call.argument<String>("artist") ?: "Unknown artist",
                        call.argument<String>("album") ?: "Unknown album"
                    )

                    result.success(true)
                }


                // =================================================
                // PAUSE
                // =================================================

                "pauseSong" -> {
                    MusicPlaybackService.command(this@MainActivity, MusicPlaybackService.ACTION_PAUSE)
                    result.success(true)
                }


                // =================================================
                // RESUME
                // =================================================

                "resumeSong" -> {
                    MusicPlaybackService.command(this@MainActivity, MusicPlaybackService.ACTION_RESUME)
                    result.success(true)
                }


                // =================================================
                // STOP
                // =================================================

                "stopSong" -> {
                    MusicPlaybackService.command(this@MainActivity, MusicPlaybackService.ACTION_STOP)
                    result.success(true)
                }


                // =================================================
                // SEEK
                // =================================================

                "seekTo" -> {

                    val position =
                        call.argument<Int>("position")
                            ?: 0

                    seekTo(
                        position,
                        result
                    )
                }


                // =================================================
                // PLAYBACK POSITION
                // =================================================

                "getPlaybackPosition" -> {

                    result.success(
                        getPlaybackPosition()
                    )
                }


                // =================================================
                // SONG DURATION
                // =================================================

                "getSongDuration" -> {

                    result.success(
                        getSongDuration()
                    )
                }


                // =================================================
                // IS PLAYING
                // =================================================

                "isPlaying" -> {
                    result.success(MusicPlaybackService.playing)
                }


                // =================================================
                // ACTIVE PLAYER
                // =================================================

                "hasActivePlayer" -> {
                    result.success(MusicPlaybackService.active)
                }


                // =================================================
                // SAVE APPEARANCE
                // =================================================

                "saveAppearance" -> {

                    val appearance =
                        call.argument<String>(
                            "appearance"
                        )

                    if (appearance.isNullOrEmpty()) {

                        result.success(false)

                        return@setMethodCallHandler
                    }

                    saveAppearance(
                        appearance
                    )

                    result.success(true)
                }


                // =================================================
                // GET APPEARANCE
                // =================================================

                "getAppearance" -> {

                    result.success(
                        getAppearance()
                    )
                }


                // =================================================
                // UNKNOWN METHOD
                // =================================================

                else -> {

                    result.notImplemented()
                }
            }
        }


        // =========================================================
        // SONG COMPLETION EVENT CHANNEL
        // =========================================================
        //
        // Flutter subscribes to:
        //
        // EventChannel(
        //     'music_player/song_events'
        // )
        //
        // Android sends "songCompleted" when MediaPlayer
        // actually reaches the end of the current song.
        //
        // =========================================================

        EventChannel(
            flutterEngine
                .dartExecutor
                .binaryMessenger,
            SONG_EVENTS_CHANNEL
        ).setStreamHandler(
            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {
                    completionEventSink = events
                }

                override fun onCancel(
                    arguments: Any?
                ) {
                    completionEventSink = null
                }
            }
        )

        ContextCompat.registerReceiver(
            this,
            serviceEventReceiver,
            android.content.IntentFilter(
                MusicPlaybackService.ACTION_SERVICE_EVENT
            ),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }


    // =============================================================
    // MEDIA PERMISSION MANAGER
    // =============================================================

    // Audio/video runtime permissions are delegated to
    // MediaPermissionManager. Video permission is intentionally
    // not requested during music startup. It can be requested
    // when the future video library is opened.


    // =============================================================
    // MEDIA FILE MANAGER
    // =============================================================

    // Rename, delete, MediaStore write access, and their activity-result
    // flows are owned by MediaFileManager.


    // =============================================================
    // RUNTIME PERMISSION RESULT
    // =============================================================

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        mediaPermissionManager.handlePermissionResult(requestCode, grantResults)
    }


    // =============================================================
    // MEDIA REQUEST RESULTS
    // =============================================================

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        mediaFileManager.handleActivityResult(
            requestCode,
            resultCode
        )
    }


    // =============================================================
    // BACKGROUND PLAYBACK SERVICE
    // =============================================================

    private fun playSong(
        uriString: String,
        title: String,
        artist: String,
        album: String
    ) {
        MusicPlaybackService.play(
            this,
            uriString,
            title,
            artist,
            album
        )
    }

    private fun seekTo(
        position: Int,
        result: MethodChannel.Result
    ) {
        MusicPlaybackService.command(
            this,
            MusicPlaybackService.ACTION_SEEK,
            position
        )
        result.success(true)
    }

    private fun getPlaybackPosition(): Int =
        MusicPlaybackService.position

    private fun getSongDuration(): Int =
        MusicPlaybackService.duration


    // =============================================================
    // SAVE APPEARANCE
    // =============================================================

    private fun saveAppearance(
        appearance: String
    ) {

        val preferences =
            getSharedPreferences(
                "music_player_settings",
                MODE_PRIVATE
            )


        preferences
            .edit()
            .putString(
                "appearance",
                appearance
            )
            .apply()
    }


    // =============================================================
    // GET APPEARANCE
    // =============================================================

    private fun getAppearance():
        String {

        val preferences =
            getSharedPreferences(
                "music_player_settings",
                MODE_PRIVATE
            )


        return preferences.getString(
            "appearance",
            "dark"
        ) ?: "dark"
    }


    // =============================================================
    // CLEANUP
    // =============================================================

    override fun onDestroy() {

        completionEventSink = null
        mediaFileManager.clearPendingResults()
        mediaPermissionManager.clearPendingResults()

        try {
            unregisterReceiver(serviceEventReceiver)
        } catch (_: Exception) {
            // Receiver may already be unregistered.
        }

        super.onDestroy()
    }
}