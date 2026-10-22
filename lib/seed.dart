import 'models.dart';

/// Programme actuel (ordre et hauteurs de la séance du 20 octobre 2026).
List<ExerciseDef> defaultRoutine() => [
      ExerciseDef(name: 'Pull ups', height: 5),
      ExerciseDef(name: 'Low row', height: 4.5),
      ExerciseDef(name: 'Press', height: 10.5),
      ExerciseDef(name: 'Poitrine flys', height: 9),
      ExerciseDef(name: 'Biceps curl', height: 5),
      ExerciseDef(name: 'Dips', height: 8),
      ExerciseDef(name: 'Knee tuck', height: 11),
      ExerciseDef(name: 'Planche', unit: Unit.seconds, height: 11),
      ExerciseDef(name: 'Tenir', unit: Unit.seconds, height: 7),
    ];

/// Exercices connus mais retirés du programme (repris depuis l'historique).
List<ExerciseDef> extraLibrary() => [
      ExerciseDef(name: 'Pistol squat', height: 4, perSide: true),
      ExerciseDef(name: 'Lunges', height: 10, perSide: true),
    ];

const _seconds = {'Planche', 'Tenir'};
const _perSide = {'Pistol squat', 'Lunges'};

/// h : null, une hauteur unique, ou une liste (une hauteur par série).
ExerciseLog _e(String name, List<int> values, [dynamic h]) {
  final sets = <SetLog>[];
  for (var i = 0; i < values.length; i++) {
    double? height;
    if (h is List) {
      height = (h[i] as num).toDouble();
    } else if (h is num) {
      height = h.toDouble();
    }
    sets.add(SetLog(values[i], height));
  }
  return ExerciseLog(
    name: name,
    unit: _seconds.contains(name) ? Unit.seconds : Unit.reps,
    perSide: _perSide.contains(name),
    sets: sets,
  );
}

Session _s(int y, int m, int d, List<ExerciseLog> ex) => Session(
      id: 'seed-$y-$m-$d',
      date: DateTime(y, m, d, 12),
      exercises: ex,
    );

/// Séances recopiées depuis tes notes (25 août → 20 octobre 2026).
List<Session> seedSessions() => [
      _s(2026, 8, 25, [
        _e('Pistol squat', [8, 8, 8, 8]),
        _e('Lunges', [12, 12, 12]),
        _e('Pull ups', [9, 6, 6]),
        _e('Low row', [15, 15, 15]),
        _e('Press', [8, 8, 8, 8], [8, 9, 9.5, 9.5]),
        _e('Poitrine flys', [12, 12, 12], [7, 8, 8]),
        _e('Biceps curl', [12, 12, 8], 5),
        _e('Dips', [12, 12, 10]),
        _e('Knee tuck', [15, 10, 12]),
        _e('Planche', [30, 30, 30]),
      ]),
      _s(2026, 8, 31, [
        _e('Pistol squat', [8, 8, 8], 4),
        _e('Lunges', [12, 12, 12], 10),
        _e('Pull ups', [9, 5, 5], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 9.5),
        _e('Poitrine flys', [12, 12, 9], 8),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 10, 10], 11.5),
        _e('Planche', [30, 30, 30], [11.5, 11, 11]),
      ]),
      _s(2026, 9, 2, [
        _e('Pistol squat', [8, 8, 8], 4),
        _e('Lunges', [12, 12, 12], 10),
        _e('Pull ups', [9, 5, 5], 5),
        _e('Low row', [15, 15, 15], [4, 4.5, 4.5]),
        _e('Press', [8, 8, 8, 8], 9.5),
        _e('Poitrine flys', [12, 12, 12], 8),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 8], 11),
        _e('Planche', [30, 30, 30], 11),
      ]),
      _s(2026, 9, 8, [
        _e('Pistol squat', [8, 8, 8], 4),
        _e('Lunges', [12, 12, 12], 10),
        _e('Pull ups', [9, 5, 5], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 9.5),
        _e('Poitrine flys', [12, 12, 12], [8, 9, 9]),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 12], 11),
        _e('Planche', [30, 30, 30], 11),
      ]),
      _s(2026, 9, 10, [
        _e('Pistol squat', [8, 8, 8], 4),
        _e('Lunges', [12, 12, 12], 10),
        _e('Pull ups', [9, 5, 5], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 9.5),
        _e('Poitrine flys', [12, 12, 12], [8, 9, 9]),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 12, 12], 11),
        _e('Planche', [30, 30, 30], 11),
      ]),
      _s(2026, 9, 16, [
        _e('Pull ups', [9, 6, 6], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 9.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 12, 12], 11),
        _e('Planche', [30, 30, 30], 11),
      ]),
      _s(2026, 9, 21, [
        _e('Pull ups', [10, 7, 7], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 12, 12], 11),
        _e('Planche', [30, 30, 30], 11),
      ]),
      _s(2026, 9, 23, [
        _e('Pull ups', [10, 7, 7], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [10, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 12, 12], 11),
        _e('Planche', [30, 30, 30], 11),
      ]),
      _s(2026, 9, 26, [
        _e('Pull ups', [10, 7, 7], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [10, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 15], 11),
        _e('Planche', [30, 30, 30], 11),
        _e('Tenir', [30, 20, 20, 20], 7),
      ]),
      _s(2026, 10, 1, [
        _e('Pull ups', [10, 7, 7], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [10, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 15], 11),
        _e('Planche', [30, 30, 30], 11),
        _e('Tenir', [30, 20, 20, 20], 7),
      ]),
      _s(2026, 10, 6, [
        _e('Pull ups', [10, 7, 7], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 15], 11),
        _e('Planche', [30, 30, 30], 11),
        _e('Tenir', [30, 20, 20, 20], 7),
      ]),
      _s(2026, 10, 13, [
        _e('Pull ups', [10, 8, 8], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 15], 11),
        _e('Planche', [30, 30, 30], 11),
        _e('Tenir', [30, 20, 20, 20], 7),
      ]),
      _s(2026, 10, 20, [
        _e('Pull ups', [10, 10, 7], 5),
        _e('Low row', [15, 15, 15], 4.5),
        _e('Press', [8, 8, 8, 8], 10.5),
        _e('Poitrine flys', [12, 12, 12], 9),
        _e('Biceps curl', [12, 12, 12], 5),
        _e('Dips', [12, 12, 12], 8),
        _e('Knee tuck', [15, 15, 11], 11),
        _e('Planche', [30, 30, 30], 11),
        _e('Tenir', [30, 20, 20, 20], 7),
      ]),
    ];
