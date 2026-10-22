import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/progress.dart';
import 'sync.dart';

class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();
  static const _storage = FlutterSecureStorage();
  static const _key = 'orbitwords.auth.session';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);
  @override
  Future<String?> accessToken() => _storage.read(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

class SupabaseRemote implements SyncRemote {
  final SupabaseClient client;
  SupabaseRemote(this.client);
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<void> push(List<LearningEvent> events) async {
    await client
        .from('learning_events')
        .upsert(
          events.map((e) => {...e.toJson(), 'user_id': userId}).toList(),
          onConflict: 'user_id,id',
          ignoreDuplicates: true,
        )
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<List<LearningEvent>> pull() async {
    final result = <LearningEvent>[];
    String? cursor;
    // Immutable UUID keys give stable keyset pagination across server row limits.
    while (true) {
      var query = client
          .from('learning_events')
          .select()
          .eq('user_id', userId!);
      if (cursor != null) {
        query = query.gt('id', cursor);
      }
      final rows = await query
          .order('id')
          .limit(500)
          .timeout(const Duration(seconds: 20));
      result.addAll(rows.map(LearningEvent.fromJson));
      if (rows.length < 500) {
        break;
      }
      cursor = rows.last['id'] as String;
    }
    return result;
  }
}
