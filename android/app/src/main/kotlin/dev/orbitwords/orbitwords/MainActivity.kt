package dev.orbitwords.orbitwords

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.SoundPool
import android.media.MediaPlayer
import android.media.PlaybackParams
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pool: SoundPool? = null
    private val samples = mutableMapOf<String, Int>()
    private val ready = mutableSetOf<Int>()
    private var stream = 0
    private var focus: AudioFocusRequest? = null
    private var focusEpoch = 0
    private var speechActive = false
    private var speechPlayer: MediaPlayer? = null
    private val manager get() = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) {
            stopAudio()
            channel?.invokeMethod("interrupted", null)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.orbitwords/learning_audio")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> {
                    if (pool != null) { result.success(ready.size == 8) }
                    else {
                        try {
                            pool = SoundPool.Builder().setMaxStreams(1).setAudioAttributes(
                                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
                            var remaining = 8
                            pool!!.setOnLoadCompleteListener { _, id, status ->
                                if (status == 0) ready.add(id)
                                remaining--
                                if (remaining == 0) result.success(ready.size == 8)
                            }
                            for (name in listOf("correct", "incorrect", "xp", "complete", "achievement", "chest", "rare", "tap", "equip", "epic", "legendary")) {
                                val target = File(cacheDir, "kvesmos-$name-v1.wav")
                                assets.open("flutter_assets/assets/audio/effects/$name.wav").use { input ->
                                    target.outputStream().use { input.copyTo(it) }
                                }
                                samples[name] = pool!!.load(target.absolutePath, 1)
                            }
                        } catch (_: Exception) {
                            pool?.release(); pool = null; samples.clear(); ready.clear()
                            result.success(false)
                        }
                    }
                }
                "allowSpeech" -> {
                    speechActive = true
                    // Explicit lesson playback follows media volume. Muting
                    // calls/notifications must not disable a requested phrase.
                    result.success(canSpeak() && takeFocus())
                }
                "speechFinished" -> {
                    if (speechActive && speechPlayer == null) stopAudio()
                    result.success(null)
                }
                "playSpeech" -> {
                    stopRecording()
                    val asset = call.argument<String>("asset") ?: ""
                    val request = call.argument<Number>("request")?.toInt()
                    if (!asset.startsWith("assets/audio/voices/") || asset.contains("..") ||
                        asset.contains(":") || asset.contains("\\") || request == null || !canSpeak() || !takeFocus()) {
                        result.success(false)
                    } else {
                        try {
                            val target = File(cacheDir, "kvesmos-speech-current")
                            assets.open("flutter_assets/$asset").use { input ->
                                target.outputStream().use { input.copyTo(it) }
                            }
                            val player = MediaPlayer()
                            speechPlayer = player
                            player.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                            player.setDataSource(target.absolutePath)
                            val volume = (call.argument<Double>("volume") ?: .85).coerceIn(0.0, 1.0).toFloat()
                            player.setVolume(volume, volume)
                            player.setOnCompletionListener {
                                if (speechPlayer === it) {
                                    stopAudio()
                                    channel?.invokeMethod("recordingFinished", request)
                                }
                            }
                            player.setOnErrorListener { failed, _, _ ->
                                if (speechPlayer === failed) {
                                    stopAudio()
                                    channel?.invokeMethod("recordingFailed", request)
                                }
                                true
                            }
                            player.prepare()
                            val rate = (call.argument<Double>("rate") ?: 1.0).coerceIn(.7, 1.0).toFloat()
                            player.playbackParams = PlaybackParams().setSpeed(rate).setPitch(1f)
                            speechActive = true
                            player.start()
                            result.success(true)
                        } catch (_: Exception) {
                            stopAudio()
                            result.success(false)
                        }
                    }
                }
                "stopSpeech" -> { stopRecording(); result.success(null) }
                "pauseSpeech" -> {
                    val player = speechPlayer
                    if (player == null) result.success(false)
                    else { player.pause(); result.success(true) }
                }
                "resumeSpeech" -> {
                    val player = speechPlayer
                    if (player == null || !canSpeak() || !takeFocus()) result.success(false)
                    else { player.start(); result.success(true) }
                }
                "play" -> {
                    val sample = samples[call.argument<String>("effect")]
                    if (sample == null || !ready.contains(sample) || !canPlay() || !takeFocus()) {
                        result.success(false)
                    } else {
                        pool?.stop(stream)
                        val volume = (call.argument<Double>("volume") ?: 0.5).coerceIn(0.0, 1.0).toFloat()
                        stream = pool!!.play(sample, volume, volume, 1, 0, 1f)
                        speechActive = false
                        val epoch = focusEpoch
                        Handler(Looper.getMainLooper()).postDelayed({
                            if (epoch == focusEpoch) stopAudio()
                        }, 800)
                        result.success(stream != 0)
                    }
                }
                "stop" -> { stopAudio(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun canPlay() = manager.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
        manager.getStreamVolume(AudioManager.STREAM_MUSIC) > 0
    private fun canSpeak() = manager.getStreamVolume(AudioManager.STREAM_MUSIC) > 0 &&
        !manager.isStreamMute(AudioManager.STREAM_MUSIC)
    @Suppress("DEPRECATION")
    private fun takeFocus(): Boolean {
        focusEpoch++
        return if (Build.VERSION.SDK_INT >= 26) {
            if (focus == null) focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setOnAudioFocusChangeListener(focusListener).build()
            manager.requestAudioFocus(focus!!) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }
    @Suppress("DEPRECATION")
    private fun stopAudio() {
        focusEpoch++
        speechActive = false
        pool?.stop(stream)
        stopRecording()
        if (Build.VERSION.SDK_INT >= 26) focus?.let { manager.abandonAudioFocusRequest(it) }
        else manager.abandonAudioFocus(focusListener)
    }
    private fun stopRecording() {
        speechPlayer?.release()
        speechPlayer = null
    }
    override fun onPause() {
        stopAudio()
        channel?.invokeMethod("interrupted", null)
        super.onPause()
    }
    override fun onDestroy() {
        stopAudio(); pool?.release(); pool = null
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
