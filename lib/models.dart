import 'dart:math';

/// Une série se mesure soit en répétitions, soit en secondes (planche, tenir).
enum Unit { reps, seconds }

Unit unitFrom(String? s) => s == 'seconds' ? Unit.seconds : Unit.reps;

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

/// Exercice du programme (ce qui est proposé quand on démarre une séance).
class ExerciseDef {
  String name;
  Unit unit;
  double? height;
  bool perSide;

  ExerciseDef({
    required this.name,
    this.unit = Unit.reps,
    this.height,
    this.perSide = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit.name,
        'height': height,
        'perSide': perSide,
      };

  factory ExerciseDef.fromJson(Map<String, dynamic> j) => ExerciseDef(
        name: j['name'] as String,
        unit: unitFrom(j['unit'] as String?),
        height: _d(j['height']),
        perSide: j['perSide'] as bool? ?? false,
      );
}

/// Une série réalisée : nombre de reps (ou secondes) + hauteur de sangle.
class SetLog {
  int value;
  double? height;

  SetLog(this.value, [this.height]);

  Map<String, dynamic> toJson() => {'v': value, 'h': height};

  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog((j['v'] as num).toInt(), _d(j['h']));
}

/// Un exercice tel qu'il a été fait pendant une séance.
class ExerciseLog {
  String name;
  Unit unit;
  bool perSide;
  List<SetLog> sets;

  ExerciseLog({
    required this.name,
    this.unit = Unit.reps,
    this.perSide = false,
    List<SetLog>? sets,
  }) : sets = sets ?? [];

  int get total => sets.fold(0, (a, s) => a + s.value);
  int get best => sets.isEmpty ? 0 : sets.map((s) => s.value).reduce(max);

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit.name,
        'perSide': perSide,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        name: j['name'] as String,
        unit: unitFrom(j['unit'] as String?),
        perSide: j['perSide'] as bool? ?? false,
        sets: (j['sets'] as List)
            .map((s) => SetLog.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

class Session {
  String id;
  DateTime date;
  List<ExerciseLog> exercises;

  Session({required this.id, required this.date, List<ExerciseLog>? exercises})
      : exercises = exercises ?? [];

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        exercises: (j['exercises'] as List)
            .map((e) => ExerciseLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Séance en cours, sauvegardée à chaque série pour survivre à une fermeture de l'app.
class WorkoutDraft {
  Session session;
  int exIndex;
  DateTime? restEndsAt;

  WorkoutDraft({required this.session, this.exIndex = 0, this.restEndsAt});

  Map<String, dynamic> toJson() => {
        'session': session.toJson(),
        'exIndex': exIndex,
        'restEndsAt': restEndsAt?.toIso8601String(),
      };

  factory WorkoutDraft.fromJson(Map<String, dynamic> j) => WorkoutDraft(
        session: Session.fromJson(Map<String, dynamic>.from(j['session'] as Map)),
        exIndex: (j['exIndex'] as num).toInt(),
        restEndsAt: j['restEndsAt'] == null
            ? null
            : DateTime.parse(j['restEndsAt'] as String),
      );
}
