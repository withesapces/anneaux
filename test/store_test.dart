import 'dart:convert';

import 'package:anneaux/models.dart';
import 'package:anneaux/stats.dart';
import 'package:anneaux/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('les données déjà enregistrées sont relues sans être modifiées', () async {
    final session = Session(
      id: 'perso-1',
      date: DateTime(2026, 10, 27, 18, 30),
      end: DateTime(2026, 10, 27, 19, 20),
      healthSynced: true,
      exercises: [
        ExerciseLog(name: 'Pull ups', sets: [SetLog(11, 5), SetLog(10, 5), SetLog(8, 5)]),
        ExerciseLog(name: 'Planche', unit: Unit.seconds, sets: [SetLog(25, 11)]),
      ],
    );
    final routine = [ExerciseDef(name: 'Pull ups', height: 5.5)];
    final draft = WorkoutDraft(session: Session(id: 'd', date: DateTime(2026, 10, 29, 18)), exIndex: 0);
    final raw = {
      'sessions_v1': jsonEncode([session.toJson()]),
      'routine_v1': jsonEncode(routine.map((r) => r.toJson()).toList()),
      'rest_seconds_v1': 90,
      'sound_v1': false,
      'health_v1': true,
      'weight_v1': 74.5,
      'kcal_v1': false,
      'draft_v1': jsonEncode(draft.toJson()),
    };
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(raw));

    final store = AppStore();
    await store.load();

    expect(store.sessions.length, 1);
    expect(store.sessions.first.id, 'perso-1');
    expect(store.sessions.first.exercises.first.total, 29);
    expect(store.routine.single.height, 5.5);
    expect(store.restSeconds, 90);
    expect(store.sound, false);
    expect(store.healthEnabled, true);
    expect(store.weightKg, 74.5);
    expect(store.sendCalories, false);
    expect(store.draft, isNotNull);

    // Le chargement ne réécrit rien.
    final p = await SharedPreferences.getInstance();
    expect(p.getString('sessions_v1'), raw['sessions_v1']);
    expect(p.getString('routine_v1'), raw['routine_v1']);
  });

  test('semaines actives : le changement d\'heure ne casse pas la série', () {
    final s = [
      Session(id: 'a', date: DateTime(2026, 10, 13, 12)),
      Session(id: 'b', date: DateTime(2026, 10, 20, 12)),
    ];
    expect(activeWeekStreak(s, DateTime(2026, 10, 29, 19)), 2);
    expect(daysSinceLast(s, DateTime(2026, 10, 29, 19)), 9);
    expect(isoWeek(DateTime(2026, 10, 29)), 44);
  });
}
