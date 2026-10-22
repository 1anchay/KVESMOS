import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var learningAudio: FlutterMethodChannel?
  private var effects: [String: AVAudioPlayer] = [:]
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
          for name in ["correct", "incorrect", "xp", "complete", "achievement", "chest", "rare", "tap"] {
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
        case "stop":
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
      } catch { result(false) }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(interruptLearningAudio), name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(interruptLearningAudio), name: UIApplication.willResignActiveNotification, object: nil)
  }
  @objc private func interruptLearningAudio() {
    effects.values.forEach { $0.stop() }
    learningAudio?.invokeMethod("interrupted", arguments: nil)
  }
}
