import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/controller.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'services/cloud.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? cloud;
  String? cloudError;
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: key,
        authOptions: const FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
        ),
      );
      cloud = Supabase.instance.client;
    } catch (_) {
      cloudError = 'Облако не запустилось. Локальное обучение доступно.';
    }
  }
  try {
    final app = AppController(
      LearningRepository(AppDatabase.open()),
      cloud: cloud,
      cloudError: cloudError,
    );
    await app.initialize();
    runApp(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => app)],
        child: const OrbitApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storage, size: 64),
                  const SizedBox(height: 20),
                  const Text(
                    'Не удалось открыть локальную базу. Проверьте свободное место и перезапустите приложение. Данные автоматически не удаляются.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: main, child: const Text('Повторить')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
