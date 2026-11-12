import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/services/account_deletion.dart';

void main() {
  test('only explicit successful server deletion allows local cleanup', () {
    requireDeletionConfirmation(200, {'deleted': true});
    for (final status in [200, 204, 401, 500]) {
      for (final body in [
        null,
        'OK',
        {},
        {'deleted': false},
        {'deleted': 'true'},
      ]) {
        expect(
          () => requireDeletionConfirmation(status, body),
          throwsStateError,
        );
      }
    }
    expect(
      () => requireDeletionConfirmation(500, {'deleted': true}),
      throwsStateError,
    );
  });
}
