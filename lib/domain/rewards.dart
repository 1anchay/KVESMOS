import 'dart:convert';
import 'dart:math';

class Cosmetic {
  final String id, name, slot, rarity, asset;
  Cosmetic(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name_ru'],
      slot = j['slot'],
      rarity = j['rarity'],
      asset = j['asset_path'];
}

class RewardCatalog {
  final List<Cosmetic> items;
  final List<Map<String, dynamic>> characters, milestones, chests;
  RewardCatalog(String raw) : this.fromJson(jsonDecode(raw));
  RewardCatalog.fromJson(Map<String, dynamic> j)
    : items = (j['cosmetics'] as List).map((e) => Cosmetic(e)).toList(),
      characters = List<Map<String, dynamic>>.from(j['characters']),
      milestones = List<Map<String, dynamic>>.from(j['milestones']),
      chests = List<Map<String, dynamic>>.from(j['chests']);
  Cosmetic item(String id) => items.firstWhere((e) => e.id == id);
  Map<String, dynamic> chest(String id) =>
      chests.firstWhere((e) => e['id'] == id);
  Map<String, double> odds(String kind, Set<String> owned) {
    final weights = Map<String, num>.from(chest(kind)['rarity_weights']);
    weights.removeWhere(
      (rarity, _) =>
          !items.any((e) => e.rarity == rarity && !owned.contains(e.id)),
    );
    final total = weights.values.fold<num>(0, (a, b) => a + b);
    return {for (final e in weights.entries) e.key: e.value / total};
  }

  Cosmetic? draw(String kind, Set<String> owned, Random random) {
    final available = odds(kind, owned);
    if (available.isEmpty) return null;
    var roll = random.nextDouble();
    var rarity = available.keys.last;
    for (final e in available.entries) {
      roll -= e.value;
      if (roll < 0) {
        rarity = e.key;
        break;
      }
    }
    final pool = items
        .where((e) => e.rarity == rarity && !owned.contains(e.id))
        .toList();
    return pool[random.nextInt(pool.length)];
  }
}

class ChestGrant {
  final String id, kind;
  final String? itemId;
  const ChestGrant(this.id, this.kind, [this.itemId]);
  Map<String, dynamic> toJson() => {
    'chestInstanceId': id,
    'grantEventId': 'grant:$id',
    'kind': kind,
    if (itemId != null) 'openEventId': 'open:$id',
    if (itemId != null) 'itemId': itemId,
  };
}

/// The transaction, rather than UI timing, decides whether this was a new find.
class RewardOpening {
  final Cosmetic? item;
  final bool fresh;
  const RewardOpening(this.item, this.fresh);
}

class Inventory {
  final Map<String, ChestGrant> grants;
  final Map<String, String> equipped;
  Inventory({Map<String, ChestGrant>? grants, Map<String, String>? equipped})
    : grants = grants ?? {},
      equipped = equipped ?? {};
  factory Inventory.decode(String? raw) {
    if (raw == null) return Inventory();
    final j = jsonDecode(raw);
    if (j['version'] != 1) {
      throw StateError('Неподдерживаемая версия коллекции.');
    }
    return Inventory(
      grants: {
        for (final e in j['grants'])
          e['chestInstanceId']: ChestGrant(
            e['chestInstanceId'],
            e['kind'],
            e['itemId'],
          ),
      },
      equipped: Map<String, String>.from(j['equipped']),
    );
  }
  Set<String> get owned =>
      grants.values.map((e) => e.itemId).whereType<String>().toSet();
  int get unopened => grants.values.where((e) => e.itemId == null).length;
  String encode() => jsonEncode({
    'version': 1,
    'grants': grants.values.map((e) => e.toJson()).toList(),
    'equipped': equipped,
  });
}
