# Сборки и выпуск

Публикация и платные услуги не выполнялись. Package ID `dev.orbitwords.orbitwords` замените на свой до регистрации приложения. Название OrbitWords и права на бренд требуют проверки. Учебный курс — независимой редактуры.

## Android

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Debug APK использует тестовую подпись. Для production создайте собственный upload keystore через keytool с интерактивным вводом пароля, сохраните резервную копию вне проекта. Создайте `android/key.properties`:

```properties
storeFile=C:/PRIVATE/orbitwords-upload.jks
storePassword=YOUR_PASSWORD
keyAlias=upload
keyPassword=YOUR_PASSWORD
```

Файл и ключи исключены из git. Не передавайте пароли через историю команд. Gradle намеренно останавливает release без signing config, debug-подпись не подставляется.

```sh
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

Добавьте настройки облака из README при необходимости. APK: `build/app/outputs/flutter-apk/`; AAB: `build/app/outputs/bundle/release/`. Увеличьте version в pubspec. Проверьте native .so и требования страниц памяти, минимальную ОС и permissions. SDK 3.47.7 задаёт compile/target API 36, NDK 28.2.13676358.

## iOS — только на macOS

В Windows IPA не собирался. Есть Flutter Xcode workspace, Runner, Info.plist, голосовые разрешения, auth URL scheme и оригинальные AppIcon.

1. Установите на Mac Flutter 3.47.7, совместимый Xcode и зависимости по `flutter doctor -v`.
2. Перенесите проект без `.tools`, `build`, `.dart_tool`. Выполните `flutter pub get` и `dart run build_runner build`.
3. Запустите `flutter build ios --simulator`, затем `flutter run` на симуляторе.
4. Откройте `ios/Runner.xcworkspace`, задайте Bundle ID, Team, signing/provisioning. Проверьте Keychain, privacy manifests SDK и разрешения.
5. Пройдите QA на настоящем iPhone, включая офлайн, перезапуск, TTS, отказ микрофона, recovery и удаление аккаунта.
6. `flutter build ipa --release` создаст архив в `build/ios/archive` и IPA в `build/ios/ipa` при настроенной подписи.
7. TestFlight/App Store выполняет владелец после приёмки. Apple Developer account не оформлялся.

Инструкции: [Flutter Android](https://docs.flutter.dev/deployment/android), [Flutter iOS](https://docs.flutter.dev/deployment/ios).

## Перед магазинами

- Завершить QA.md, редактуру курса и физические испытания.
- Заполнить оператора/контакты/сроки в PRIVACY.md, разместить политику на стабильном HTTPS URL и связать с карточкой магазина и приложением.
- Развернуть и испытать удаление аккаунта. Подготовить внешний способ запроса удаления и ссылку для Google Play: [Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en), [Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
- Заполнить Data safety / App Privacy по фактическим данным и SDK. Не заявлять отсутствие данных при включённом облаке. Сверить [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- Определить аудиторию и возрастные ограничения; отсутствие рекламы само по себе не подтверждает соответствие детским требованиям.
- Подготовить реальные скриншоты, поддержку, резервные копии и порядок обработки запросов.

Это инженерная подготовка, не гарантия одобрения магазина.
