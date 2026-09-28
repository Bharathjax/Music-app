package com.example.music_player

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {

    private val CHANNEL =
        "music_player/device_music"

    private val SONG_EVENTS_CHANNEL =
        "music_player/song_events"

    private val MUSIC_PERMISSION_REQUEST_CODE =
        1001

    private var permissionResult:
        MethodChannel.Result? = null

    private var mediaPlayer:
        MediaPlayer? = null

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
                        getArtwork(uriString)
                    )
                }


                // =================================================
                // MUSIC PERMISSION
                // =================================================

                "requestMusicPermission" -> {

                    requestMusicPermission(
                        result
                    )
                }


                // =================================================
                // GET DEVICE SONGS
                // =================================================

                "getDeviceSongs" -> {

                    if (hasMusicPermission()) {

                        result.success(
                            getDeviceSongs()
                        )

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
                        result
                    )
                }


                // =================================================
                // PAUSE
                // =================================================

                "pauseSong" -> {

                    pauseSong()

                    result.success(true)
                }


                // =================================================
                // RESUME
                // =================================================

                "resumeSong" -> {

                    resumeSong()

                    result.success(true)
                }


                // =================================================
                // STOP
                // =================================================

                "stopSong" -> {

                    stopSong()

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

                    result.success(
                        mediaPlayer?.isPlaying == true
                    )
                }


                // =================================================
                // ACTIVE PLAYER
                // =================================================

                "hasActivePlayer" -> {

                    result.success(
                        mediaPlayer != null
                    )
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

                    completionEventSink =
                        events
                }


                override fun onCancel(
                    arguments: Any?
                ) {

                    completionEventSink =
                        null
                }
            }
        )
    }


    // =============================================================
    // MUSIC PERMISSION
    // =============================================================

    private fun hasMusicPermission():
        Boolean {

        val permission =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU
            ) {

                Manifest.permission.READ_MEDIA_AUDIO

            } else {

                Manifest.permission.READ_EXTERNAL_STORAGE
            }

        return ContextCompat.checkSelfPermission(
            this,
            permission
        ) == PackageManager.PERMISSION_GRANTED
    }


    // =============================================================
    // REQUEST MUSIC PERMISSION
    // =============================================================

    private fun requestMusicPermission(
        result: MethodChannel.Result
    ) {

        if (hasMusicPermission()) {

            result.success(true)

            return
        }

        permissionResult =
            result

        val permission =
            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.TIRAMISU
            ) {

                Manifest.permission.READ_MEDIA_AUDIO

            } else {

                Manifest.permission.READ_EXTERNAL_STORAGE
            }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(permission),
            MUSIC_PERMISSION_REQUEST_CODE
        )
    }


    // =============================================================
    // PERMISSION RESULT
    // =============================================================

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {

        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )


        if (
            requestCode !=
            MUSIC_PERMISSION_REQUEST_CODE
        ) {

            return
        }


        val granted =
            grantResults.isNotEmpty() &&
            grantResults[0] ==
            PackageManager.PERMISSION_GRANTED


        permissionResult?.success(
            granted
        )

        permissionResult = null
    }


    // =============================================================
    // GET DEVICE SONGS
    // =============================================================

    private fun getDeviceSongs():
        List<Map<String, Any?>> {

        val songs =
            mutableListOf<Map<String, Any?>>()


        val collection =
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI


        val projection =
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION
            )


        val selection =
            "${MediaStore.Audio.Media.IS_MUSIC} != 0"


        val sortOrder =
            "${MediaStore.Audio.Media.TITLE} ASC"


        contentResolver.query(
            collection,
            projection,
            selection,
            null,
            sortOrder
        )?.use { cursor ->


            val idColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media._ID
                )


            val titleColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.TITLE
                )


            val artistColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.ARTIST
                )


            val albumColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.ALBUM
                )


            val durationColumn =
                cursor.getColumnIndexOrThrow(
                    MediaStore.Audio.Media.DURATION
                )


            while (cursor.moveToNext()) {


                val id =
                    cursor.getLong(
                        idColumn
                    )


                val title =
                    cursor.getString(
                        titleColumn
                    ) ?: "Unknown title"


                val artist =
                    cursor.getString(
                        artistColumn
                    ) ?: "Unknown artist"


                val album =
                    cursor.getString(
                        albumColumn
                    ) ?: "Unknown album"


                val duration =
                    cursor.getLong(
                        durationColumn
                    )


                val contentUri =
                    "${MediaStore.Audio.Media.EXTERNAL_CONTENT_URI}/$id"


                songs.add(
                    mapOf(
                        "id" to id,
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "duration" to duration,
                        "uri" to contentUri
                    )
                )
            }
        }


        return songs
    }


    // =============================================================
    // FUNCTION: GET SONG ARTWORK
    // =============================================================

    private fun getArtwork(
        uriString: String
    ): ByteArray? {

        val retriever =
            MediaMetadataRetriever()


        return try {

            val uri =
                Uri.parse(uriString)


            retriever.setDataSource(
                this,
                uri
            )


            retriever.embeddedPicture

        } catch (e: Exception) {

            null

        } finally {

            retriever.release()
        }
    }


    // =============================================================
    // PLAY SONG
    // =============================================================

    private fun playSong(
        uriString: String,
        result: MethodChannel.Result
    ) {

        try {

            // Release the previous player first.
            mediaPlayer?.release()

            mediaPlayer = null


            val uri =
                Uri.parse(uriString)


            // Create a completely new MediaPlayer
            // for the selected song.
            mediaPlayer =
                MediaPlayer.create(
                    this,
                    uri
                )


            if (mediaPlayer == null) {

                result.error(
                    "PLAYBACK_ERROR",
                    "Unable to create MediaPlayer.",
                    null
                )

                return
            }


            // =====================================================
            // IMPORTANT:
            //
            // Tell Flutter when the song really finishes.
            //
            // Previously this callback was empty, which meant
            // Flutter had to detect the end using position polling.
            //
            // =====================================================

            mediaPlayer?.setOnCompletionListener {

                completionEventSink?.success(
                    "songCompleted"
                )
            }


            // Start playback immediately.
            mediaPlayer?.start()


            result.success(true)

        } catch (e: Exception) {

            result.error(
                "PLAYBACK_ERROR",
                e.message,
                null
            )
        }
    }


    // =============================================================
    // PAUSE
    // =============================================================

    private fun pauseSong() {

        if (
            mediaPlayer?.isPlaying == true
        ) {

            mediaPlayer?.pause()
        }
    }


    // =============================================================
    // RESUME
    // =============================================================

    private fun resumeSong() {

        try {

            mediaPlayer?.start()

        } catch (e: Exception) {

            // Ignore resume error.
        }
    }


    // =============================================================
    // STOP
    // =============================================================

    private fun stopSong() {

        try {

            mediaPlayer?.stop()

        } catch (e: Exception) {

            // Player may already be stopped.
        }


        mediaPlayer?.release()

        mediaPlayer = null
    }


    // =============================================================
    // SEEK
    // =============================================================

    private fun seekTo(
        position: Int,
        result: MethodChannel.Result
    ) {

        try {

            val player =
                mediaPlayer


            if (player == null) {

                result.success(false)

                return
            }


            val duration =
                player.duration


            val safePosition =
                position.coerceIn(
                    0,
                    duration
                )


            player.seekTo(
                safePosition
            )


            result.success(true)

        } catch (e: Exception) {

            result.error(
                "SEEK_ERROR",
                e.message,
                null
            )
        }
    }


    // =============================================================
    // GET PLAYBACK POSITION
    // =============================================================

    private fun getPlaybackPosition():
        Int {

        return try {

            mediaPlayer?.currentPosition
                ?: 0

        } catch (e: Exception) {

            0
        }
    }


    // =============================================================
    // GET SONG DURATION
    // =============================================================

    private fun getSongDuration():
        Int {

        return try {

            mediaPlayer?.duration
                ?: 0

        } catch (e: Exception) {

            0
        }
    }


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

        mediaPlayer?.release()

        mediaPlayer = null

        super.onDestroy()
    }
}