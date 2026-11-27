import 'dart:convert';

import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/first_flight.dart';

Future<void> saveCompletedFirstFlight(LearningRepository learning) =>
    learning.setSetting(
      FirstFlightRepository.key,
      jsonEncode(
        (FirstFlight()
              ..room = FlightRoom.bridge
              ..revision = 26
              ..learned.addAll(FlightWord.values)
              ..inventory.add(FlightItem.key)
              ..milestones.addAll([
                'unlocked',
                'charged',
                'wired',
                'powered',
                'requested',
                'locker',
                'navigable',
                'complete',
              ]))
            .toJson(),
      ),
    );
