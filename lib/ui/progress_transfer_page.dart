import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';
import '../data/progress_transfer.dart';
import '../domain/progress.dart';
import 'design.dart';
import 'flight_components.dart';

class ProgressTransferPage extends ConsumerStatefulWidget {
  const ProgressTransferPage({super.key});

  @override
  ConsumerState<ProgressTransferPage> createState() =>
      _ProgressTransferPageState();
}

class _ProgressTransferPageState extends ConsumerState<ProgressTransferPage> {
  static const _documents = MethodChannel('dev.orbitwords/progress_documents');
  bool _busy = false;
  String? _status;
  ProgressFile? _file;
  TransferPreview? _preview;

  Future<void> _run(Future<void> Function(ProgressTransfer) action) async {
    if (_busy) return;
    final app = ref.read(appProvider);
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action(ProgressTransfer(app.repository, app.rewards.catalog));
    } on FormatException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => _status = e.code == 'size'
              ? 'Файл превышает 32 МБ.'
              : 'Системные файлы недоступны. Проверьте папку и попробуйте снова.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Операцию не удалось завершить. Попробуйте снова.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run((transfer) async {
    final bytes = await transfer.export();
    if (!mounted) return;
    final saved = await _documents.invokeMethod<bool>('export', {
      'name': 'KVESMOS-progress-${dayKey(transfer.learning.now())}.json',
      'bytes': bytes,
    });
    if (mounted && saved == true) {
      setState(() => _status = 'Копия прогресса сохранена.');
    }
  });

  Future<void> _open() => _run((transfer) async {
    setState(() {
      _file = null;
      _preview = null;
    });
    final bytes = await _documents.invokeMethod<Uint8List>('open');
    if (bytes == null || !mounted) return;
    final file = await transfer.validate(bytes);
    final preview = await transfer.preview(file);
    if (mounted) {
      setState(() {
        _file = file;
        _preview = preview;
      });
    }
  });

  Future<void> _restore() => _run((transfer) async {
    final app = ref.read(appProvider);
    await transfer.restore(_file!);
    if (mounted) {
      setState(() {
        _file = null;
        _preview = null;
        _status = 'Прогресс восстановлен. Уже полученные награды учтены.';
      });
    }
    await app.reloadTransferredProgress();
  });

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final type = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Перенос прогресса')),
      body: pageBody([
        Text('Сохранение и перенос прогресса', style: type.headlineSmall),
        const Text(
          'Один файл для истории пяти курсов, коллекции и начатых занятий.',
        ),
        const SizedBox(height: 12),
        const FlightPanel(
          child: Text(
            'В файле есть имя и история занятий. Файл без шифрования. '
            'Выберите личную папку или носитель, доступный только вам. '
            'Храните копию отдельно от приложения.',
          ),
        ),
        const SizedBox(height: 16),
        if (!Platform.isAndroid)
          const Text('Системный перенос прогресса доступен на Android.'),
        if (Platform.isAndroid) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.save_alt),
            label: const Text('Экспортировать'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _open,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Восстановить из файла'),
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_status != null) Semantics(liveRegion: true, child: Text(_status!)),
        if (preview != null) ...[
          const SizedBox(height: 16),
          FlightPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Предпросмотр копии', style: type.titleLarge),
                Text('Дата: ${dayKey(_file!.created.toLocal())}'),
                Text('XP на телефоне: ${preview.currentXp}'),
                Text('XP в копии: ${preview.fileXp}'),
                Text('XP после объединения: ${preview.mergedXp}'),
                Text('Новых событий: ${preview.newEvents}'),
                Text(
                  'В копии: уроков ${preview.fileLessons}, черновиков ${preview.drafts}, '
                  'предметов ${preview.items}, открытых сундуков ${preview.opened}.',
                ),
                const SizedBox(height: 8),
                Text(
                  preview.freshProfile
                      ? 'Профиль, оформление и настройки из файла будут восстановлены.'
                      : 'Локальные настройки и черновики с одинаковым шагом сохранятся. '
                            'История и коллекции объединятся.',
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Объединить прогресс'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _preview = null;
                    _file = null;
                  }),
            child: const Text('Отмена'),
          ),
        ],
      ]),
    );
  }
}
