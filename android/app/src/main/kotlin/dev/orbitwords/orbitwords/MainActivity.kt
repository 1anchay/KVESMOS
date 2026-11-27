package dev.orbitwords.orbitwords

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import java.util.TimeZone
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
    private var learningSpeech: LearningSpeech? = null
    private var progressDocuments: ProgressDocuments? = null
    private var companionChannel: MethodChannel? = null
    private var channel: MethodChannel? = null
    private var pool: SoundPool? = null
    private val samples = mutableMapOf<String, Int>()
    private val ready = mutableSetOf<Int>()
    private var stream = 0
    private var focus: AudioFocusRequest? = null
    private var focusRegistered = false
    private var focused = false
    private var focusLost = false
    private var active = false
    private var flutterActive = true
    private var mic = false
    private var unplugged = false
    private var receiverRegistered = false
    private var scene = "silent"
    private val soundscape by lazy { FlightSoundscape(this) }
    private val audioHandler = Handler(Looper.getMainLooper())
    private val expireEffect = Runnable { stopEffects(); releaseIdleFocus() }
    private var prepareResults = mutableListOf<MethodChannel.Result>()
    private val effectNames = ("correct incorrect xp complete achievement chest rare tap equip " +
        "epic legendary interact pickup chapter token returnToken confirm radio door power trust " +
        "location cast line bite tension reel splash catchFish escapeFish recordFish").split(" ")
    private var speechActive = false
    private var speechPlayer: MediaPlayer? = null
    private var pendingSpeech: MethodChannel.Result? = null
    private var lastSpeechProblem: String? = null
    private val manager get() = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val audioAvailable get() = active && flutterActive && !mic && !unplugged
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (focusRegistered) {
            focused = change == AudioManager.AUDIOFOCUS_GAIN
            if (focused) soundscape.apply(audioAvailable)
            else {
                if (change == AudioManager.AUDIOFOCUS_LOSS) {
                    focusLost = true
                    abandonFocus()
                }
                interruptAudio()
            }
        }
    }
    private val unplugReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != AudioManager.ACTION_AUDIO_BECOMING_NOISY) return
            unplugged = true
            interruptAudio()
            abandonFocus()
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(DailyCompanion.OPEN_COURSE)?.let {
            // Android can reuse the activity while Dart is still starting.
            // Keep the extra for consumeLaunch until Dart acknowledges it.
            companionChannel?.invokeMethod("openCourse", DailyCompanion.course(it), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (this@MainActivity.intent === intent) intent.removeExtra(DailyCompanion.OPEN_COURSE)
                }
                override fun error(code: String, message: String?, details: Any?) {}
                override fun notImplemented() {}
            })
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeControlStream = AudioManager.STREAM_MUSIC
        learningSpeech = LearningSpeech(this, flutterEngine.dartExecutor.binaryMessenger) { recording ->
            mic = recording
            if (recording) {
                interruptAudio()
                abandonFocus()
            } else refreshMix()
        }
        val unplugFilter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(unplugReceiver, unplugFilter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(unplugReceiver, unplugFilter)
        receiverRegistered = true
        progressDocuments = ProgressDocuments(this, flutterEngine.dartExecutor.binaryMessenger)
        companionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.orbitwords/daily_companion")
        companionChannel!!.setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    "consumeLaunch" -> { val id = intent.getStringExtra(DailyCompanion.OPEN_COURSE); intent.removeExtra(DailyCompanion.OPEN_COURSE); result.success(id) }
                    "sync" -> { DailyCompanion.sync(this, call.arguments as String); result.success(null) }
                    "pinWidget" -> result.success(DailyCompanion.pin(this))
                    "timezone" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("companion", e.message, null) }
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.orbitwords/learning_audio")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> {
                    if (pool != null) {
                        if (prepareResults.isEmpty()) result.success(ready.size == effectNames.size)
                        else prepareResults.add(result)
                    }
                    else {
                        try {
                            prepareResults.add(result)
                            pool = SoundPool.Builder().setMaxStreams(1).setAudioAttributes(
                                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()).build()
                            var remaining = effectNames.size
                            pool!!.setOnLoadCompleteListener { loaded, id, status ->
                                if (pool !== loaded) return@setOnLoadCompleteListener
                                if (status == 0) ready.add(id)
                                remaining--
                                if (remaining == 0) finishPreparation(ready.size == effectNames.size)
                            }
                            for (name in effectNames) {
                                val target = File(cacheDir, "kvesmos-$name-v1.wav")
                                assets.open("flutter_assets/assets/audio/effects/$name.wav").use { input ->
                                    target.outputStream().use { input.copyTo(it) }
                                }
                                val id = pool!!.load(target.absolutePath, 1)
                                if (id == 0) remaining-- else samples[name] = id
                            }
                            if (remaining == 0) finishPreparation(ready.size == effectNames.size)
                        } catch (_: Exception) {
                            pool?.release(); pool = null; samples.clear(); ready.clear()
                            finishPreparation(false)
                        }
                    }
                }
                "soundscape" -> {
                    val next = call.argument<String>("scene") ?: "silent"
                    val nextActive = call.argument<Boolean>("foreground") == true
                    val changedContext = next != scene || nextActive && !flutterActive
                    if (changedContext) {
                        unplugged = false
                        focusLost = false
                    }
                    scene = next
                    flutterActive = nextActive
                    soundscape.configure(scene, call.argument<Double>("music")?.toFloat() ?: 0f,
                        call.argument<Double>("ambience")?.toFloat() ?: 0f,
                        call.argument<Boolean>("duck") == true)
                    refreshMix()
                    result.success(null)
                }
                "soundscapeStatus" -> result.success(soundscape.status())
                "allowSpeech" -> {
                    val allowed = permitSpeech()
                    result.success(allowed)
                }
                "audioStatus" -> result.success(mapOf(
                    "volume" to manager.getStreamVolume(AudioManager.STREAM_MUSIC),
                    "maximum" to manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                    "muted" to manager.isStreamMute(AudioManager.STREAM_MUSIC),
                    "problem" to lastSpeechProblem))
                "speechFinished" -> {
                    if (speechActive && speechPlayer == null) endSpeech()
                    result.success(null)
                }
                "playSpeech" -> {
                    stopRecording()
                    val asset = call.argument<String>("asset") ?: ""
                    val request = call.argument<Number>("request")?.toInt()
                    if (!asset.startsWith("assets/audio/voices/") || asset.contains("..") ||
                        asset.contains(":") || asset.contains("\\") || request == null || !permitSpeech()) {
                        result.success(false)
                    } else {
                        try {
                            val player = MediaPlayer()
                            speechPlayer = player
                            pendingSpeech = result
                            player.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                            val path = "flutter_assets/$asset"
                            try {
                                assets.openFd(path).use {
                                    player.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                                }
                            } catch (_: java.io.IOException) {
                                val target = File(cacheDir, "kvesmos-speech-current")
                                assets.open(path).use { input ->
                                    target.outputStream().use { input.copyTo(it) }
                                }
                                player.setDataSource(target.absolutePath)
                            }
                            val volume = (call.argument<Double>("volume") ?: .85).coerceIn(0.0, 1.0).toFloat()
                            player.setVolume(volume, volume)
                            player.setOnCompletionListener {
                                if (speechPlayer === it) {
                                    endSpeech()
                                    channel?.invokeMethod("recordingFinished", request)
                                }
                            }
                            player.setOnErrorListener { failed, _, _ ->
                                if (speechPlayer === failed) {
                                    lastSpeechProblem = "decoder"
                                    endSpeech()
                                    channel?.invokeMethod("recordingFailed", request)
                                }
                                true
                            }
                            val rate = (call.argument<Double>("rate") ?: 1.0).coerceIn(.7, 1.0).toFloat()
                            speechActive = true
                            player.setOnPreparedListener {
                                if (speechPlayer === it) {
                                    try {
                                        it.start()
                                        if (rate != 1f) it.playbackParams = PlaybackParams().setSpeed(rate).setPitch(1f)
                                        android.util.Log.i("KVESMOSAudio", "bundled playback started, rate=$rate")
                                        pendingSpeech?.success(true)
                                        pendingSpeech = null
                                    } catch (_: Exception) {
                                        lastSpeechProblem = "decoder"
                                        endSpeech()
                                    }
                                }
                            }
                            player.prepareAsync()
                        } catch (_: Exception) {
                            lastSpeechProblem = "asset"
                            val pending = pendingSpeech
                            endSpeech()
                            if (pending == null) result.success(false)
                        }
                    }
                }
                "stopSpeech" -> { endSpeech(); result.success(null) }
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
                    if (sample == null || !ready.contains(sample) || speechActive ||
                        !audioAvailable || focusLost || !canPlay() || !takeFocus()) {
                        result.success(false)
                    } else {
                        stopEffects()
                        val volume = (call.argument<Double>("volume") ?: 0.5).coerceIn(0.0, 1.0).toFloat()
                        stream = pool!!.play(sample, volume, volume, 1, 0, 1f)
                        audioHandler.postDelayed(expireEffect, 1600)
                        result.success(stream != 0)
                    }
                }
                "stop" -> { stopEffects(); releaseIdleFocus(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun finishPreparation(success: Boolean) {
        val waiting = prepareResults
        prepareResults = mutableListOf()
        for (result in waiting) result.success(success)
    }
    private fun canPlay() = manager.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
        manager.getStreamVolume(AudioManager.STREAM_MUSIC) > 0
    private fun canSpeak() = manager.getStreamVolume(AudioManager.STREAM_MUSIC) > 0 &&
        !manager.isStreamMute(AudioManager.STREAM_MUSIC)
    private fun permitSpeech(): Boolean {
        if (active && flutterActive && !mic) {
            unplugged = false
            focusLost = false
        }
        lastSpeechProblem = when {
            !canSpeak() -> "muted"
            !audioAvailable || !takeFocus() -> "focus"
            else -> null
        }
        if (lastSpeechProblem == null) {
            stopEffects()
            speechActive = true
            refreshMix()
        }
        return lastSpeechProblem == null
    }
    @Suppress("DEPRECATION")
    private fun takeFocus(): Boolean {
        if (focusRegistered) return focused
        focused = if (Build.VERSION.SDK_INT >= 26) {
            if (focus == null) focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setWillPauseWhenDucked(true)
                .setOnAudioFocusChangeListener(focusListener).build()
            manager.requestAudioFocus(focus!!) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else manager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        focusRegistered = focused
        return focused
    }
    @Suppress("DEPRECATION")
    private fun abandonFocus() {
        if (!focusRegistered) return
        focusRegistered = false
        focused = false
        if (Build.VERSION.SDK_INT >= 26) focus?.let { manager.abandonAudioFocusRequest(it) }
        else manager.abandonAudioFocus(focusListener)
    }
    private fun refreshMix() {
        val playing = audioAvailable && soundscape.wanted &&
            !focusLost && (focused || takeFocus())
        soundscape.apply(playing)
        releaseIdleFocus()
    }
    private fun releaseIdleFocus() {
        if (!audioAvailable || (!soundscape.wanted && !speechActive && stream == 0)) abandonFocus()
    }
    private fun stopEffects() {
        audioHandler.removeCallbacks(expireEffect)
        pool?.stop(stream)
        stream = 0
    }
    private fun endSpeech() {
        speechActive = false
        stopRecording()
        releaseIdleFocus()
    }
    private fun interruptAudio() {
        soundscape.apply(false)
        stopEffects()
        endSpeech()
        channel?.invokeMethod("interrupted", null)
    }
    private fun stopRecording() {
        pendingSpeech?.success(false)
        pendingSpeech = null
        speechPlayer?.release()
        speechPlayer = null
    }
    override fun onResume() {
        super.onResume()
        active = true
        unplugged = false
        focusLost = false
        refreshMix()
    }
    override fun onPause() {
        active = false
        learningSpeech?.interrupt()
        interruptAudio()
        abandonFocus()
        super.onPause()
    }
    @Deprecated("Android document picker result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (progressDocuments?.onResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
    override fun onDestroy() {
        active = false
        learningSpeech?.dispose()
        progressDocuments?.dispose()
        if (receiverRegistered) unregisterReceiver(unplugReceiver)
        stopEffects()
        endSpeech()
        abandonFocus()
        soundscape.release()
        pool?.release()
        pool = null
        finishPreparation(false)
        channel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        learningSpeech?.onPermissionResult(requestCode)
    }
}
