package dev.orbitwords.orbitwords

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.io.File
import java.io.IOException

internal class FlightSoundscape(private val context: Context) {
    private class Track(val name: String, val player: MediaPlayer) {
        var prepared = false
        var gain = 0f
        var from = 0f
        var target = 0f
        var changedAt = 0L
    }

    private class Layer {
        var current: Track? = null
        var outgoing: Track? = null
    }

    private val handler = Handler(Looper.getMainLooper())
    private val music = Layer()
    private val ambience = Layer()
    private val layers = listOf(music, ambience)
    private val tick = Runnable { updateVolumes() }
    private var scene = "silent"
    private var musicVolume = 0f
    private var ambienceVolume = 0f
    private var ducked = false
    private var enabled = false
    private var starts = 0

    private val musicName get() = scene.takeIf { it in setOf("menu", "ship", "exploration", "water") }
    private val ambientName get() = when (scene) {
        "ship" -> "ship_room"
        "water" -> "water_shore"
        else -> null
    }
    val wanted get() = (musicName != null && musicVolume > 0f) ||
        (ambientName != null && ambienceVolume > 0f)

    fun configure(scene: String, music: Float, ambience: Float, ducked: Boolean) {
        this.scene = scene
        musicVolume = music
        ambienceVolume = ambience
        this.ducked = ducked
    }

    fun apply(enabled: Boolean) {
        this.enabled = enabled
        if (!enabled) {
            handler.removeCallbacks(tick)
            for (layer in layers) {
                layer.outgoing?.player?.release()
                layer.outgoing = null
                layer.current?.let { track ->
                    if (track.prepared && track.player.isPlaying) track.player.pause()
                    track.gain = 0f
                    track.target = 0f
                    track.player.setVolume(0f, 0f)
                }
            }
        }
        switch(music, musicName, musicVolume * if (ducked) .22f else 1f, fade = enabled)
        switch(ambience, ambientName, ambienceVolume * if (ducked) .15f else 1f, fade = false)
        if (enabled) updateVolumes()
    }

    private fun switch(layer: Layer, name: String?, volume: Float, fade: Boolean) {
        if (layer.current?.name != name) {
            val previous = layer.current
            val returning = layer.outgoing?.takeIf { it.name == name }
            if (returning == null) layer.outgoing?.player?.release()
            layer.outgoing = null
            layer.current = returning
            if (previous != null && fade && previous.prepared) {
                layer.outgoing = previous
                target(previous, 0f)
            } else previous?.player?.release()
        }
        if (enabled && name != null && volume > 0f && layer.current == null) {
            load(layer, name)
        }
        layer.current?.let {
            if (enabled) {
                target(it, volume)
                if (volume > 0f && it.prepared && !it.player.isPlaying) it.player.start()
            }
        }
    }

    private fun target(track: Track, volume: Float) {
        if (track.target == volume) return
        track.from = track.gain
        track.target = volume
        track.changedAt = SystemClock.uptimeMillis()
    }

    private fun load(layer: Layer, name: String) {
        val player = MediaPlayer()
        val track = Track(name, player)
        layer.current = track
        try {
            player.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            val path = "flutter_assets/assets/audio/game/$name.ogg"
            try {
                context.assets.openFd(path).use {
                    player.setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
            } catch (_: IOException) {
                val target = File(context.cacheDir, "kvesmos-game-v1-$name.ogg")
                context.assets.open(path).use { input ->
                    target.outputStream().use { input.copyTo(it) }
                }
                player.setDataSource(target.absolutePath)
            }
            player.setVolume(0f, 0f)
            player.isLooping = true
            player.setOnPreparedListener {
                if (layer.current !== track) return@setOnPreparedListener
                track.prepared = true
                track.gain = 0f
                track.from = 0f
                track.changedAt = SystemClock.uptimeMillis()
                if (enabled && track.target > 0f) {
                    it.start()
                    starts++
                    updateVolumes()
                }
            }
            player.setOnErrorListener { _, _, _ ->
                if (layer.current === track) layer.current = null
                if (layer.outgoing === track) layer.outgoing = null
                player.release()
                true
            }
            player.prepareAsync()
        } catch (_: Exception) {
            layer.current = null
            player.release()
        }
    }

    private fun updateVolumes() {
        handler.removeCallbacks(tick)
        if (!enabled) return
        val now = SystemClock.uptimeMillis()
        var fading = false
        for (layer in layers) {
            for (track in listOfNotNull(layer.current, layer.outgoing)) {
                if (!track.prepared) continue
                val fraction = ((now - track.changedAt) / 320f).coerceIn(0f, 1f)
                val eased = fraction * fraction * (3f - 2f * fraction)
                track.gain = track.from + (track.target - track.from) * eased
                track.player.setVolume(track.gain, track.gain)
                if (fraction < 1f && track.from != track.target) fading = true
                if (track.gain == 0f && track.target == 0f) {
                    if (layer.outgoing === track) {
                        layer.outgoing = null
                        track.player.release()
                    } else if (track.player.isPlaying) track.player.pause()
                }
            }
        }
        if (fading) handler.postDelayed(tick, 24)
    }

    fun status() = mapOf(
        "scene" to scene,
        "starts" to starts,
        "musicGain" to (music.current?.gain ?: 0f).toDouble(),
        "ambienceGain" to (ambience.current?.gain ?: 0f).toDouble(),
        "running" to layers.any { layer ->
            layer.current?.let { it.prepared && it.player.isPlaying } == true
        },
        "players" to layers.sumOf { listOfNotNull(it.current, it.outgoing).size }
    )

    fun release() {
        handler.removeCallbacks(tick)
        for (layer in layers) {
            layer.current?.player?.release()
            layer.outgoing?.player?.release()
            layer.current = null
            layer.outgoing = null
        }
    }
}
