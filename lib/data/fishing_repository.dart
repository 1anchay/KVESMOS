import 'dart:convert';

import '../domain/fishing.dart';
import 'first_flight_repository.dart';
import 'repository.dart';

class FishingCatch {
  const FishingCatch(
    this.id,
    this.trip,
    this.result,
    this.discovery,
    this.record,
  );

  final String id, trip;
  final FishingResult result;
  final bool discovery, record;
  SpaceFish get fish => result.fish!;

  List<Object> encode() => [
    trip,
    fish.name,
    result.grams,
    result.cm,
    result.zone.name,
    (discovery ? 1 : 0) + (record ? 2 : 0),
  ];

  static FishingCatch decode(String id, Object? value) {
    final row = value as List;
    final trip = row[0] as String;
    final fish = SpaceFish.values.byName(row[1] as String);
    final grams = row[2] as int;
    final cm = row[3] as int;
    final zone = FishingZone.values.byName(row[4] as String);
    final flags = row[5] as int;
    if (row.length != 6 ||
        !FishingSave.validId(id) ||
        !FishingSave.validId(trip) ||
        grams < fish.minGrams ||
        grams > fish.maxGrams ||
        cm < fish.minCm ||
        cm > fish.maxCm ||
        flags < 0 ||
        flags > 3) {
      throw const FormatException('Некорректный улов');
    }
    return FishingCatch(
      id,
      trip,
      FishingResult.caught(fish, grams, cm, zone),
      flags & 1 != 0,
      flags & 2 != 0,
    );
  }
}

class FishingSave {
  FishingSave();
  final catches = <String, FishingCatch>{};
  final reports = <String, int>{};
  String? activeTrip;
  int level = 0;
  bool comfort = false;
  FishingRod rod = FishingRod.scout;
  FishingBait bait = FishingBait.glimmer;

  static final _id = RegExp(r'^[a-f0-9-]{36}$');
  static bool validId(String id) => _id.hasMatch(id);

  int get earned => catches.values.fold(0, (n, c) => n + c.fish.rarity.samples);
  int get samples => earned - FishingUpgrade.spent(level);
  int get record =>
      catches.values.fold(0, (n, c) => c.result.grams > n ? c.result.grams : n);
  String? get lastReport => reports.entries
      .fold<MapEntry<String, int>?>(
        null,
        (last, entry) =>
            last == null || entry.value >= last.value ? entry : last,
      )
      ?.key;
  List<FishingCatch> forTrip(String trip) => [
    for (final entry in catches.values)
      if (entry.trip == trip) entry,
  ];
  List<FishingCatch> forSpecies(SpaceFish fish) => [
    for (final entry in catches.values)
      if (entry.fish == fish) entry,
  ];

  String encode() => jsonEncode({
    'c': catches.map((id, item) => MapEntry(id, item.encode())),
    'reports': reports,
    'trip': activeTrip,
    'level': level,
    'comfort': comfort,
    'rod': rod.name,
    'bait': bait.name,
  });

  factory FishingSave.decode(String? raw) {
    if (raw == null) return FishingSave();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final save = FishingSave()
        ..activeTrip = json['trip'] as String?
        ..level = json['level'] as int
        ..comfort = json['comfort'] as bool
        ..rod = FishingRod.values.byName(json['rod'] as String)
        ..bait = FishingBait.values.byName(json['bait'] as String)
        ..reports.addAll(Map<String, int>.from(json['reports'] as Map));
      for (final entry in (json['c'] as Map<String, dynamic>).entries) {
        save.catches[entry.key] = FishingCatch.decode(entry.key, entry.value);
      }
      final active = save.activeTrip;
      if (save.level < 0 ||
          save.level > FishingUpgrade.values.length ||
          save.rod.level > save.level ||
          save.samples < 0 ||
          save.reports.entries.any((e) => !validId(e.key) || e.value < 0) ||
          (active != null &&
              (!validId(active) || save.reports.containsKey(active))) ||
          save.catches.values.any(
            (c) => c.trip != active && !save.reports.containsKey(c.trip),
          )) {
        throw const FormatException('Некорректный журнал рыбалки');
      }
      return save;
    } catch (_) {
      throw const FormatException('Некорректный журнал рыбалки');
    }
  }

  /// Outcomes are merged by attempt id. Currency and records are derived from
  /// those outcomes, so importing a profile twice cannot award anything twice.
  void merge(FishingSave source) {
    for (final c in source.catches.values) {
      catches.putIfAbsent(c.id, () => c);
    }
    for (final report in source.reports.entries) {
      reports.update(
        report.key,
        (old) => old > report.value ? old : report.value,
        ifAbsent: () => report.value,
      );
    }
    if (activeTrip case final local? when reports.containsKey(local)) {
      activeTrip = null;
    }
    if (source.activeTrip case final incoming?
        when !reports.containsKey(incoming)) {
      if (activeTrip == null) {
        activeTrip = incoming;
      } else if (activeTrip != incoming) {
        // Accounts may have an unfinished excursion on a second device.
        // Preserve any landed fish as an archived trip.
        reports[incoming] = 0;
      }
    }
    if (source.level > level && FishingUpgrade.spent(source.level) <= earned) {
      level = source.level;
    }
  }
}

class FishingRepository {
  FishingRepository(this.learning);
  static const key = 'kvesmos.fishing.v1:ru-en';
  final LearningRepository learning;

  Future<FishingSave> read() async =>
      FishingSave.decode(await learning.setting(key));
  Future<void> _write(FishingSave save) =>
      learning.setSetting(key, save.encode());

  Future<FishingSave> depart(String trip) => learning.db.transaction(() async {
    final save = await read();
    if (!FishingSave.validId(trip) ||
        !(await FirstFlightRepository(learning).read()).complete) {
      throw StateError('Сначала заверши первый полёт.');
    }
    if (save.activeTrip == null && !save.reports.containsKey(trip)) {
      save.activeTrip = trip;
      await _write(save);
    }
    return save;
  });

  Future<({FishingSave save, FishingCatch entry})> land(
    String trip,
    String attempt,
    FishingResult result,
  ) => learning.db.transaction(() async {
    final save = await read();
    if (save.catches[attempt] case final existing? when existing.trip == trip) {
      return (save: save, entry: existing);
    }
    final fish = result.fish;
    if (fish == null ||
        save.activeTrip != trip ||
        !FishingSave.validId(attempt) ||
        save.catches.containsKey(attempt) ||
        result.grams < fish.minGrams ||
        result.grams > fish.maxGrams ||
        result.cm < fish.minCm ||
        result.cm > fish.maxCm) {
      throw StateError('Попытка уже завершена или улов недоступен.');
    }
    final discovered = !save.catches.values.any((c) => c.fish == fish);
    final entry = FishingCatch(
      attempt,
      trip,
      result,
      discovered,
      result.grams > save.record,
    );
    save.catches[attempt] = entry;
    await _write(save);
    return (save: save, entry: entry);
  });

  Future<FishingSave> finish(String trip) => learning.db.transaction(() async {
    final save = await read();
    if (save.activeTrip == trip) {
      save.activeTrip = null;
      save.reports.putIfAbsent(
        trip,
        () => learning.now().millisecondsSinceEpoch,
      );
      await _write(save);
    }
    return save;
  });

  Future<FishingSave> equipment({
    FishingRod? rod,
    FishingBait? bait,
    bool? comfort,
    FishingUpgrade? buy,
  }) => learning.db.transaction(() async {
    final save = await read();
    if (buy != null && buy.index == save.level && buy.price <= save.samples) {
      save.level++;
    }
    if (rod != null && rod.level <= save.level) save.rod = rod;
    save.bait = bait ?? save.bait;
    save.comfort = comfort ?? save.comfort;
    await _write(save);
    return save;
  });
}
