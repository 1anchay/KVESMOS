/// Never erase local data merely because an endpoint returned HTTP 200.
void requireDeletionConfirmation(int status, Object? body) {
  if (status < 200 ||
      status >= 300 ||
      body is! Map ||
      body['deleted'] != true) {
    throw StateError(
      'Сервер не подтвердил удаление. Локальные данные сохранены.',
    );
  }
}
