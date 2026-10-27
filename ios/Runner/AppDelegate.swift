import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVAudioPlayerDelegate {
  private var learningAudio: FlutterMethodChannel?
  private var effects: [String: AVAudioPlayer] = [:]
  private var speechPlayer: AVAudioPlayer?
  private var speechRequest: Int?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KVESMOSLearningAudio") else { return }
    learningAudio = FlutterMethodChannel(name: "dev.orbitwords/learning_audio", binaryMessenger: registrar.messenger())
    learningAudio?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      do {
        switch call.method {
        case "prepare":
          try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
          for name in ["correct", "incorrect", "xp", "complete", "achievement", "chest", "rare", "tap", "equip", "epic", "legendary"] {
            let key = FlutterDartProject.lookupKey(forAsset: "assets/audio/effects/\(name).wav")
            if let path = Bundle.main.path(forResource: key, ofType: nil) {
              let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
              player.prepareToPlay()
              self.effects[name] = player
            }
          }
          result(self.effects.count == 8)
        case "allowSpeech": result(true)
        case "speechFinished": result(nil)
        case "playSpeech":
          self.stopSpeech()
          let args = call.arguments as? [String: Any] ?? [:]
          guard let asset = args["asset"] as? String,
                asset.hasPrefix("assets/audio/voices/"), !asset.contains(".."),
                !asset.contains(":"), !asset.contains("\\"),
                let request = args["request"] as? Int else { result(false); return }
          let key = FlutterDartProject.lookupKey(forAsset: asset)
          guard let path = Bundle.main.path(forResource: key, ofType: nil) else { result(false); return }
          try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
          try AVAudioSession.sharedInstance().setActive(true)
          let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
          player.delegate = self
          player.enableRate = true
          player.rate = Float(min(1, max(0.7, args["rate"] as? Double ?? 1)))
          player.volume = Float(min(1, max(0, args["volume"] as? Double ?? 0.85)))
          self.speechPlayer = player
          self.speechRequest = request
          result(player.play())
        case "stopSpeech": self.stopSpeech(); result(nil)
        case "pauseSpeech":
          guard let player = self.speechPlayer else { result(false); return }
          player.pause(); result(true)
        case "resumeSpeech":
          guard let player = self.speechPlayer else { result(false); return }
          try AVAudioSession.sharedInstance().setActive(true)
          result(player.play())
        case "stop":
          self.stopSpeech()
          self.effects.values.forEach { $0.stop(); $0.currentTime = 0 }
          result(nil)
        case "play":
          let args = call.arguments as? [String: Any] ?? [:]
          self.effects.values.forEach { $0.stop(); $0.currentTime = 0 }
          if let name = args["effect"] as? String, let player = self.effects[name] {
            player.volume = Float(args["volume"] as? Double ?? 0.5)
            result(player.play())
          } else { result(false) }
        default: result(FlutterMethodNotImplemented)
        }
      } catch { self.stopSpeech(); result(false) }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(interruptLearningAudio), name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(interruptLearningAudio), name: UIApplication.willResignActiveNotification, object: nil)
  }
  @objc private func interruptLearningAudio() {
    stopSpeech()
    effects.values.forEach { $0.stop() }
    learningAudio?.invokeMethod("interrupted", arguments: nil)
  }
  private func stopSpeech() {
    speechPlayer?.stop()
    speechPlayer = nil
    speechRequest = nil
  }
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard player === speechPlayer, let request = speechRequest else { return }
    stopSpeech()
    learningAudio?.invokeMethod(flag ? "recordingFinished" : "recordingFailed", arguments: request)
  }
  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    audioPlayerDidFinishPlaying(player, successfully: false)
  }
}
