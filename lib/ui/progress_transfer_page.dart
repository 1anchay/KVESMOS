import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/controller.dart';
import '../data/progress_encryption.dart';
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
  bool _legacy = false;

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
    final password = await _password(protect: true);
    if (password == null || !mounted) return;
    final bytes = await ProgressEncryption.encrypt(
      await transfer.export(),
      password,
    );
    if (!mounted) return;
    final saved = await _documents.invokeMethod<bool>('export', {
      'name': 'KVESMOS-progress-${dayKey(transfer.learning.now())}.kvesmos',
      'bytes': bytes,
    });
    if (mounted && saved == true) {
      setState(() => _status = 'Защищённая копия сохранена.');
    }
  });

  Future<void> _open() => _run((transfer) async {
    setState(() {
      _file = null;
      _preview = null;
    });
    final bytes = await _documents.invokeMethod<Uint8List>('open');
    if (bytes == null || !mounted) return;
    final encrypted = ProgressEncryption.isEncrypted(bytes);
    final password = encrypted ? await _password(protect: false) : null;
    if (!mounted || encrypted && password == null) return;
    final file = await transfer.validate(
      encrypted ? await ProgressEncryption.decrypt(bytes, password!) : bytes,
    );
    final preview = await transfer.preview(file);
    if (mounted) {
      setState(() {
        _file = file;
        _preview = preview;
        _legacy = !encrypted;
      });
    }
  });

  Future<String?> _password({required bool protect}) => showDialog<String>(
    context: context,
    builder: (_) => _BackupPasswordDialog(protect: protect),
  );

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
            'Новая копия защищена паролем. Сохраните пароль отдельно: '
            'без него восстановить копию нельзя. В старых JSON-файлах имя '
            'и история занятий открыты любому, у кого есть файл.',
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
                if (_legacy) const Text('Старая копия без шифрования.'),
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

class _BackupPasswordDialog extends StatefulWidget {
  final bool protect;
  const _BackupPasswordDialog({required this.protect});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.protect ? 'Защитить копию' : 'Открыть копию'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 256,
            decoration: const InputDecoration(labelText: 'Пароль'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите пароль';
              }
              if (widget.protect && value.trim().runes.length < 12) {
                return 'Введите минимум 12 символов';
              }
              return null;
            },
            textInputAction: widget.protect
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: widget.protect ? null : (_) => _submit(),
          ),
          if (widget.protect)
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 256,
              decoration: const InputDecoration(labelText: 'Повторите пароль'),
              validator: (value) =>
                  value == _password.text ? null : 'Пароли не совпадают',
              onFieldSubmitted: (_) => _submit(),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.protect ? 'Сохранить' : 'Открыть'),
      ),
    ],
  );
}
