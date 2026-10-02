package com.example.music_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat

class MusicPlaybackService : Service() {

    companion object {
        const val ACTION_PLAY = "com.example.music_player.PLAY"
        const val ACTION_PAUSE = "com.example.music_player.PAUSE"
        const val ACTION_RESUME = "com.example.music_player.RESUME"
        const val ACTION_STOP = "com.example.music_player.STOP"
        const val ACTION_SEEK = "com.example.music_player.SEEK"
        const val ACTION_NEXT = "com.example.music_player.NEXT"
        const val ACTION_PREVIOUS = "com.example.music_player.PREVIOUS"

        const val ACTION_SERVICE_EVENT = "com.example.music_player.SERVICE_EVENT"
        const val EXTRA_EVENT = "event"
        const val EVENT_COMPLETED = "songCompleted"
        const val EVENT_NEXT = "nextSong"
        const val EVENT_PREVIOUS = "previousSong"
        const val EVENT_PAUSED = "paused"
        const val EVENT_RESUMED = "resumed"

        const val EXTRA_URI = "uri"
        const val EXTRA_TITLE = "title"
        const val EXTRA_ARTIST = "artist"
        const val EXTRA_ALBUM = "album"
        const val EXTRA_POSITION = "position"

        private const val CHANNEL_ID = "music_playback"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var active: Boolean = false
            private set

        @Volatile
        var playing: Boolean = false
            private set

        @Volatile
        var position: Int = 0
            private set

        @Volatile
        var duration: Int = 0
            private set

        fun play(context: Context, uri: String, title: String, artist: String, album: String?) {
            val intent = Intent(context, MusicPlaybackService::class.java).apply {
                action = ACTION_PLAY
                putExtra(EXTRA_URI, uri)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_ARTIST, artist)
                putExtra(EXTRA_ALBUM, album ?: "Unknown album")
            }
            startServiceCompat(context, intent)
        }

        fun command(context: Context, action: String, position: Int? = null) {
            val intent = Intent(context, MusicPlaybackService::class.java).apply {
                this.action = action
                if (position != null) putExtra(EXTRA_POSITION, position)
            }
            startServiceCompat(context, intent)
        }

        private fun startServiceCompat(context: Context, intent: Intent) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                androidx.core.content.ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private lateinit var mediaSession: MediaSessionCompat
    private val handler = Handler(Looper.getMainLooper())

    private var currentUri: String? = null
    private var currentTitle: String = "Music"
    private var currentArtist: String = "Unknown artist"
    private var currentAlbum: String = "Unknown album"
    private var albumArt: Bitmap? = null

    private val audioNoisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                pausePlayback()
                sendFlutterEvent(EVENT_PAUSED)
            }
        }
    }

    private val progressRunnable = object : Runnable {
        override fun run() {
            val player = mediaPlayer
            if (player != null) {
                position = try { player.currentPosition } catch (_: Exception) { 0 }
                duration = try { player.duration } catch (_: Exception) { 0 }
                updatePlaybackState()
                updateNotification()
            }
            if (active) handler.postDelayed(this, 1000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        val noisyFilter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                audioNoisyReceiver,
                noisyFilter,
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(audioNoisyReceiver, noisyFilter)
        }

        mediaSession = MediaSessionCompat(this, "MusicPlayerSession")
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() = resumePlayback()
            override fun onPause() = pausePlayback()
            override fun onStop() = stopPlayback()
            override fun onSeekTo(pos: Long) = seekPlayback(pos.toInt())
            override fun onSkipToNext() = sendFlutterEvent(EVENT_NEXT)
            override fun onSkipToPrevious() = sendFlutterEvent(EVENT_PREVIOUS)
        })
        mediaSession.isActive = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                val uri = intent.getStringExtra(EXTRA_URI)
                if (!uri.isNullOrEmpty()) {
                    playPlayback(
                        uri,
                        intent.getStringExtra(EXTRA_TITLE) ?: "Music",
                        intent.getStringExtra(EXTRA_ARTIST) ?: "Unknown artist",
                        intent.getStringExtra(EXTRA_ALBUM) ?: "Unknown album"
                    )
                }
            }
            ACTION_PAUSE -> pausePlayback()
            ACTION_RESUME -> resumePlayback()
            ACTION_STOP -> stopPlayback()
            ACTION_SEEK -> seekPlayback(intent.getIntExtra(EXTRA_POSITION, 0))
            ACTION_NEXT -> sendFlutterEvent(EVENT_NEXT)
            ACTION_PREVIOUS -> sendFlutterEvent(EVENT_PREVIOUS)
        }
        return START_STICKY
    }

    private fun playPlayback(uriString: String, title: String, artist: String, album: String) {
        try {
            mediaPlayer?.release()
            mediaPlayer = null

            currentUri = uriString
            currentTitle = title
            currentArtist = artist
            currentAlbum = album
            albumArt = loadArtwork(uriString)

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(this@MusicPlaybackService, Uri.parse(uriString))
                setOnPreparedListener {
                    MusicPlaybackService.duration = it.duration
                    MusicPlaybackService.active = true
                    MusicPlaybackService.playing = true
                    startForeground(NOTIFICATION_ID, buildNotification())
                    it.start()
                    handler.removeCallbacks(progressRunnable)
                    handler.post(progressRunnable)
                    updatePlaybackState()
                }
                setOnCompletionListener {
                    playing = false
                    position = duration
                    updatePlaybackState()
                    updateNotification()
                    sendFlutterEvent(EVENT_COMPLETED)
                }
                setOnErrorListener { _, _, _ ->
                    playing = false
                    active = false
                    updatePlaybackState()
                    stopForegroundCompat()
                    true
                }
                startForeground(NOTIFICATION_ID, buildNotification())
                prepareAsync()
            }
        } catch (e: Exception) {
            playing = false
            active = false
            mediaPlayer?.release()
            mediaPlayer = null
            stopForegroundCompat()
        }
    }

    private fun pausePlayback() {
        try {
            mediaPlayer?.pause()
            playing = false
            position = mediaPlayer?.currentPosition ?: position
            updatePlaybackState()
            updateNotification()
        } catch (_: Exception) {}
    }

    private fun resumePlayback() {
        try {
            val player = mediaPlayer ?: return
            if (!player.isPlaying) player.start()
            active = true
            playing = true
            startForeground(NOTIFICATION_ID, buildNotification())
            updatePlaybackState()
            updateNotification()

            // Keep Flutter UI synchronized when playback resumes
            // from a native/MediaSession action.
            sendFlutterEvent(EVENT_RESUMED)
        } catch (_: Exception) {}
    }

    private fun seekPlayback(newPosition: Int) {
        try {
            val safe = newPosition.coerceIn(0, mediaPlayer?.duration ?: 0)
            mediaPlayer?.seekTo(safe)
            position = safe
            updatePlaybackState()
            updateNotification()
        } catch (_: Exception) {}
    }

    private fun stopPlayback() {
        handler.removeCallbacks(progressRunnable)
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        mediaPlayer?.release()
        mediaPlayer = null
        active = false
        playing = false
        position = 0
        duration = 0
        currentUri = null
        mediaSession.isActive = false
        stopForegroundCompat()
        stopSelf()
    }

    private fun updatePlaybackState() {
        if (!::mediaSession.isInitialized) return
        val state = if (playing) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val actions = PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_STOP or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(state, position.toLong(), 1.0f)
                .build()
        )
        mediaSession.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, currentAlbum)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration.toLong())
                .apply {
                    albumArt?.let {
                        putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, it)
                    }
                }
                .build()
        )
        mediaSession.isActive = true
    }

    private fun buildNotification(): Notification {
        val previousIntent = PendingIntent.getService(
            this, 11, Intent(this, MusicPlaybackService::class.java).setAction(ACTION_PREVIOUS),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val playPauseAction = if (playing) {
            NotificationCompat.Action(android.R.drawable.ic_media_pause, "Pause", servicePendingIntent(ACTION_PAUSE, 12))
        } else {
            NotificationCompat.Action(android.R.drawable.ic_media_play, "Play", servicePendingIntent(ACTION_RESUME, 12))
        }
        val nextIntent = servicePendingIntent(ACTION_NEXT, 13)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(currentTitle)
            .setContentText(currentArtist)
            .setLargeIcon(albumArt)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .addAction(NotificationCompat.Action(android.R.drawable.ic_media_previous, "Previous", previousIntent))
            .addAction(playPauseAction)
            .addAction(NotificationCompat.Action(android.R.drawable.ic_media_next, "Next", nextIntent))
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
    }

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, MusicPlaybackService::class.java).setAction(action)
        return PendingIntent.getService(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun updateNotification() {
        if (!active) return
        getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Music playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Music playback controls"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    private fun loadArtwork(uriString: String): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(this, Uri.parse(uriString))
            retriever.embeddedPicture?.let { bytes ->
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
        } catch (_: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun sendFlutterEvent(event: String) {
        sendBroadcast(
            Intent(ACTION_SERVICE_EVENT).setPackage(packageName)
                .putExtra(EXTRA_EVENT, event)
        )
    }

    override fun onDestroy() {
        handler.removeCallbacks(progressRunnable)
        try {
            unregisterReceiver(audioNoisyReceiver)
        } catch (_: Exception) {
        }
        try { mediaPlayer?.release() } catch (_: Exception) {}
        mediaPlayer = null
        active = false
        playing = false
        mediaSession.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
