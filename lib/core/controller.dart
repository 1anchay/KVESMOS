import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repository.dart';
import '../data/rewards_repository.dart';
import '../data/missions_repository.dart';
import '../domain/missions.dart';
import '../domain/rewards.dart';
import '../domain/progress.dart';
import '../domain/explorer_profile.dart';
import '../services/cloud.dart';
import '../services/sync.dart';
import '../services/learning_audio.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError('Override at startup'),
);

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  static const showcaseKey = 'kvesmos.profile.showcase.v1';
  final LearningRepository repository;
  final Random? rewardRandom;
  final SupabaseClient? cloud;
  late final SyncService? sync;
  late final RewardsRepository rewards;
  late final MissionsRepository dailyMissions;
  late final LearningAudio audio;
  MissionSnapshot? missions;
  Inventory inventory = Inventory();
  List<String> featuredAchievements = [];
  ProgressSnapshot progress = ProgressSnapshot();
  ExplorerRecords records = const ExplorerRecords();
  Set<String> installed = {};
  int goal = 50;
  String name = 'Исследователь', startingLevel = 'С нуля';
  ThemeMode theme = ThemeMode.system;
  bool onboarded = false;
  bool recoveringPassword = false, syncPaused = false;
  bool _disposed = false;
  String? cloudError;
  Timer? _retry;
  Timer? _calendarTimer;
  StreamSubscription<AuthState>? _auth;
  AppController(
    this.repository, {
    this.cloud,
    this.cloudError,
    this.rewardRandom,
  }) {
    audio = LearningAudio(repository.setting, repository.setSetting);
    sync = cloud == null
        ? null
        : SyncService(repository, SupabaseRemote(cloud!));
  }
  Future<void> initialize() async {
    await repository.initialize();
    await audio.initialize();
    rewards = RewardsRepository(
      repository,
      RewardCatalog(await repository.loadAsset('assets/kvesmos/catalog.json')),
      random: rewardRandom,
    );
    dailyMissions = MissionsRepository(repository);
    goal = int.tryParse(await repository.setting('goal') ?? '') ?? 50;
    name = await repository.setting('name') ?? 'Исследователь';
    startingLevel = await repository.setting('level') ?? 'С нуля';
    onboarded = await repository.setting('onboarded') == 'true';
    try {
      final saved = jsonDecode(await repository.setting(showcaseKey) ?? '[]');
      if (saved is List) {
        featuredAchievements = saved
            .whereType<String>()
            .toSet()
            .take(3)
            .toList();
      }
    } on FormatException {
      featuredAchievements = [];
    }
    final savedTheme = await repository.setting('theme');
    theme = ThemeMode.values.firstWhere(
      (t) => t.name == savedTheme,
      orElse: () => ThemeMode.system,
    );
    await refresh();
    WidgetsBinding.instance.addObserver(this);
    _auth = cloud?.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        recoveringPassword = true;
        notifyListeners();
      }
      unawaited(synchronize());
    });
    _retry = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(synchronize());
      unawaited(_refreshCalendar());
    });
    _scheduleCalendar();
    unawaited(synchronize());
  }

  Future<void> initializeAfterReset() async {
    await audio.initialize();
    featuredAchievements = [];
    recoveringPassword = false;
    goal = 50;
    name = 'Исследователь';
    startingLevel = 'С нуля';
    theme = ThemeMode.system;
    onboarded = false;
    await repository.initialize();
    await refresh();
  }

  Future<void> refresh() async {
    final events = await repository.allEvents();
    progress = ProgressSnapshot.fromEvents(events);
    records = ExplorerRecords.fromEvents(events, progress);
    installed = await repository.installed();
    await rewards.reconcile();
    missions = await dailyMissions.reconcile();
    inventory = missions!.inventory;
    if (!_disposed) notifyListeners();
  }

  /// Durable presentation marker only; never grants XP or inventory items.
  Future<bool> claimExperienceMoment(String id) =>
      repository.db.transaction(() async {
        final key = 'kvesmos.alive.seen.v1:$id';
        if (await repository.setting(key) != null) return false;
        await repository.setSetting(key, 'true');
        return true;
      });

  Future<void> equipCosmetic(String slot, String? id) async {
    inventory = await rewards.equip(slot, id);
    if (!_disposed) notifyListeners();
  }

  Future<void> resetAppearance() async {
    inventory = await rewards.resetAppearance();
    if (!_disposed) notifyListeners();
  }

  Future<void> saveShowcase(List<String> names) async {
    final selected = names.toSet().toList();
    if (selected.length > 3 ||
        selected.any((n) => !progress.achievements.contains(n))) {
      throw StateError('Выберите до трёх уже полученных достижений.');
    }
    await repository.setSetting(showcaseKey, jsonEncode(selected));
    featuredAchievements = selected;
    if (!_disposed) notifyListeners();
  }

  void _scheduleCalendar() {
    _calendarTimer?.cancel();
    if (_disposed) return;
    final now = repository.now();
    final tomorrow = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _calendarTimer = Timer(
      tomorrow.difference(now) + const Duration(milliseconds: 10),
      () => unawaited(_refreshCalendar()),
    );
  }

  Future<void> _refreshCalendar() async {
    if (_disposed) return;
    try {
      if (missions?.day != dayKey(repository.now())) await refresh();
    } catch (_) {
      // Keep the durable snapshot and retry on the next minute or resume.
    } finally {
      _scheduleCalendar();
    }
  }

  Future<void> changeAccount(Future<void> Function() action) async {
    if (sync?.busy == true) {
      throw StateError('Дождитесь завершения синхронизации.');
    }
    syncPaused = true;
    try {
      await action();
    } finally {
      syncPaused = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> synchronize() async {
    if (_disposed || syncPaused || sync == null || sync!.busy) {
      return;
    }
    try {
      final operation = sync!.run();
      notifyListeners();
      await operation;
      cloudError = null;
    } catch (e) {
      cloudError = e is StateError
          ? e.message
          : 'Проверьте сеть и настройки Supabase.';
    }
    if (!_disposed) await refresh();
  }

  Future<void> savePreferences({
    String? newName,
    int? newGoal,
    ThemeMode? newTheme,
    String? level,
  }) async {
    if (newName != null) {
      final savedName = newName.trim().isEmpty
          ? 'Исследователь'
          : newName.trim();
      await repository.setSetting('name', savedName);
      name = savedName;
    }
    if (newGoal != null) {
      goal = newGoal;
      await repository.setSetting('goal', '$goal');
    }
    if (newTheme != null) {
      theme = newTheme;
      await repository.setSetting('theme', theme.name);
    }
    if (level != null) {
      startingLevel = level;
      await repository.setSetting('level', level);
    }
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    await repository.setSetting('onboarded', 'true');
    onboarded = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(audio.stop());
    if (state == AppLifecycleState.resumed) {
      audio.voices.scanned = false;
      unawaited(_refreshCalendar());
      unawaited(synchronize());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(audio.stop());
    _retry?.cancel();
    _calendarTimer?.cancel();
    _auth?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> saveAudio(AudioPreferences preferences) async {
    await audio.save(preferences);
    if (!_disposed) notifyListeners();
  }
}
