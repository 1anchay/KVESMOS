package dev.orbitwords.orbitwords

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class LearningSpeech(
    private val activity: Activity, messenger: BinaryMessenger, private val onMic: (Boolean) -> Unit
) {
    private val channel = MethodChannel(messenger, "dev.orbitwords/learning_device")
    private val handler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var token: Int? = null
    private var permission: MethodChannel.Result? = null
    private val deadline = Runnable { token?.let { finish(it, "timeout") } }
    private val preferences = activity.getSharedPreferences("learning_device", Activity.MODE_PRIVATE)

    private fun granted() = activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED
    private fun localAvailable() = Build.VERSION.SDK_INT >= 31 &&
        SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
    private fun systemAvailable() = SpeechRecognizer.isRecognitionAvailable(activity)
    private fun permissionState() = when {
        granted() -> "granted"
        preferences.getBoolean("mic_requested", false) &&
            !activity.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO) -> "blocked"
        else -> "denied"
    }

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "speechStatus" -> result.success(mapOf(
                        "permission" to permissionState(),
                        "offline" to localAvailable(), "system" to systemAvailable()))
                    "requestMic" -> when {
                        permissionState() != "denied" -> result.success(permissionState())
                        permission != null -> result.success("busy")
                        else -> {
                            permission = result
                            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST)
                        }
                    }
                    "startSpeech" -> result.success(start(
                        requireNotNull(call.argument<Int>("token")),
                        requireNotNull(call.argument<String>("locale")),
                        call.argument<Boolean>("network") == true))
                    "stopSpeech" -> {
                        if (token == call.argument<Int>("token")) {
                            if (call.argument<Boolean>("cancel") == true) clear()
                            else recognizer?.stopListening()
                        }
                        result.success(null)
                    }
                    "keyboardSettings", "appSettings", "voiceSettings" -> {
                        val intent = when (call.method) {
                            "keyboardSettings" -> Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
                            "appSettings" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:${activity.packageName}"))
                            else -> Intent("com.android.settings.TTS_SETTINGS")
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("device_unavailable", null, null)
            }
        }
    }

    fun onPermissionResult(request: Int) {
        if (request != REQUEST) return
        preferences.edit().putBoolean("mic_requested", true).apply()
        permission?.success(permissionState())
        permission = null
    }

    private fun start(id: Int, locale: String, network: Boolean): String {
        if (!granted()) return permissionState()
        if (token != null) return "busy"
        if (locale !in setOf("en-US", "es-ES", "de-DE", "fr-FR", "zh-CN")) return "locale"
        if (network && !systemAvailable()) return "service"
        if (!network && !localAvailable()) return if (systemAvailable()) "offline" else "service"
        val engine = try {
            if (!network && Build.VERSION.SDK_INT >= 31)
                SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
            else SpeechRecognizer.createSpeechRecognizer(activity)
        } catch (_: Exception) { return if (network) "service" else "offline" }
        recognizer = engine
        token = id
        try {
            onMic(true)
            engine.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = emit(id, "listening")
                override fun onBeginningOfSpeech() = emit(id, "speaking")
                override fun onEndOfSpeech() = emit(id, "processing")
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
                override fun onError(error: Int) = finish(id, "android_$error")
                override fun onPartialResults(results: Bundle?) = emit(id, "partial", words(results))
                override fun onResults(results: Bundle?) = finish(id, "final", words(results))
            })
            engine.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true))
            handler.postDelayed(deadline, 18000)
            return "started"
        } catch (_: Exception) {
            clear()
            return "service"
        }
    }

    private fun words(results: Bundle?) =
        results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()

    private fun emit(id: Int, state: String, words: String? = null) {
        if (token == id) channel.invokeMethod("speechEvent", mapOf("token" to id, "state" to state, "words" to words))
    }

    private fun finish(id: Int, state: String, words: String? = null) {
        if (token != id) return
        emit(id, state, words)
        clear()
    }

    private fun clear() {
        val wasRecording = token != null
        token = null
        handler.removeCallbacks(deadline)
        val previous = recognizer
        recognizer = null
        previous?.destroy()
        if (wasRecording) onMic(false)
    }

    fun interrupt() { token?.let { finish(it, "interrupted") } }

    fun dispose() {
        clear()
        permission?.success("interrupted")
        permission = null
        channel.setMethodCallHandler(null)
    }

    companion object { private const val REQUEST = 9282 }
}
