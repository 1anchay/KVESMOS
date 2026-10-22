# Подключение Supabase

Проект не создан и не подключён; перед публикацией необходим приёмочный тест реального сервера.

1. Создайте собственное тестовое окружение Supabase. Решение об оплате — только владельца.
2. Примените `supabase/migrations/202610210001_learning_events.sql` через SQL Editor / CLI migrations.
3. Включите Email/password и подтверждение email. Проверьте доставку писем, настройте SMTP и лимиты для production.
4. Auth → URL Configuration: разрешите `dev.orbitwords://auth-callback`. Схема прописана в Android и iOS; production рекомендуется перевести на собственные проверенные Universal/App Links.
5. Выполните `supabase functions deploy delete-account`. Функция проверяет пользователя через `auth.getUser()`, а admin API вызывает только на сервере. Gateway JWT-настройку согласуйте с типом ключей вашего проекта; проверку пользователя внутри функции не отключайте.
6. Передайте URL и publishable/anon key через `--dart-define`, см. README. Service role хранится только на сервере.
7. Запустите `supabase/tests/rls.sql` на тестовой базе и двухустройственные сценарии из QA.md.

Сессия хранится через `flutter_secure_storage` в Keychain / защищённом хранилище Android. Android backup отключён. SQLite отдельно не шифруется, защищается sandbox ОС. Простой выход сохраняет локальное обучение; перед передачей устройства другому человеку очистите локальные данные.

RLS: `auth.uid() = user_id`, только SELECT / INSERT. Клиент не изменяет старые события, retry использует ON CONFLICT DO NOTHING. Удаление аккаунта каскадно удаляет события. Старый токен удалённого пользователя не позволит вставить данные из-за foreign key. Гость не получает доступа к таблице.

Не создавайте публичный рейтинг на этих данных: клиентское XP не защищено от намеренной модификации. Изоляция данных не означает античит.

Источники: [Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [deleteUser](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser).
