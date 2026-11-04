import 'dart:convert';

import 'package:anneaux/backup.dart';
import 'package:anneaux/models.dart';
import 'package:anneaux/seed.dart';
import 'package:flutter_test/flutter_test.dart';

String _export() => const JsonEncoder.withIndent(' ').convert({
      'version': 1,
      'restSeconds': 120,
      'routine': defaultRoutine().map((r) => r.toJson()).toList(),
      'sessions': seedSessions().map((s) => s.toJson()).toList(),
    });

void main() {
  test('un export de l\'app se relit tel quel', () {
    final b = parseBackup(_export());
    expect(b.sessions.length, seedSessions().length);
    expect(b.routine.length, defaultRoutine().length);
    expect(b.restSeconds, 120);
    expect(b.range!.$1, DateTime(2026, 8, 25, 12));
    expect(b.range!.$2, DateTime(2026, 10, 20, 12));
  });

  test('espaces insécables, invisibles et guillemets typographiques sont réparés', () {
    final abime = '﻿Ma sauvegarde :\n${_export()}\n\nEnvoyé de mon Samsung'
        .replaceAll(' "', ' “')
        .replaceAll('",', '”,​');
    final b = parseBackup(abime);
    expect(b.sessions.length, seedSessions().length);
    expect(b.sessions.last.exercises.first.name, isNotEmpty);
  });

  test('un texte coupé est signalé comme incomplet', () {
    final raw = _export();
    expect(
      () => parseBackup(raw.substring(0, raw.length ~/ 2)),
      throwsA(isA<BackupException>()
          .having((e) => e.message, 'message', contains('incomplète'))),
    );
  });

  test('un texte quelconque est refusé avec un message clair', () {
    expect(() => parseBackup('bonjour'), throwsA(isA<BackupException>()));
    expect(() => parseBackup('{"a": 1}'), throwsA(isA<BackupException>()));
  });

  test('les séances sans hauteur ni fin restent valides', () {
    final s = Session(id: 'x', date: DateTime(2026, 10, 27, 18), exercises: [
      ExerciseLog(name: 'Pull ups', sets: [SetLog(10)]),
    ]);
    final raw = jsonEncode({
      'version': 1,
      'routine': [],
      'sessions': [s.toJson()],
    });
    final b = parseBackup(raw);
    expect(b.sessions.single.exercises.single.sets.single.height, isNull);
    expect(b.restSeconds, isNull);
  });
}
