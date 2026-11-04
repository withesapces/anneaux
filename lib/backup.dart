import 'dart:convert';

import 'models.dart';

/// Erreur de lecture d'une sauvegarde, avec un message lisible pour l'utilisateur.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// Contenu d'une sauvegarde, lu mais pas encore appliqué.
class Backup {
  final List<Session> sessions;
  final List<ExerciseDef> routine;
  final int? restSeconds;

  const Backup({required this.sessions, required this.routine, this.restSeconds});

  /// Séance la plus ancienne et la plus récente (null si aucune séance).
  (DateTime, DateTime)? get range {
    if (sessions.isEmpty) return null;
    final dates = sessions.map((s) => s.date).toList()..sort();
    return (dates.first, dates.last);
  }
}

/// Répare ce que les applis de notes, de mail ou de messagerie ajoutent
/// quand on copie-colle la sauvegarde : espaces insécables, caractères
/// invisibles, guillemets typographiques, texte avant/après (signature…).
String cleanBackupText(String raw) {
  var s = raw
      .replaceAll('﻿', '')
      .replaceAll(RegExp('[​‌‍⁠]'), '')
      .replaceAll(RegExp('[   ]'), ' ')
      .replaceAll(RegExp('[“”„‟″]'), '"')
      .replaceAll('\r\n', '\n');
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0) {
    throw const BackupException(
        'Le presse-papiers ne contient pas de sauvegarde Anneaux.');
  }
  if (end < start) {
    throw BackupException(_truncated(s.length));
  }
  return s.substring(start, end + 1);
}

String _truncated(int length) =>
    'Sauvegarde incomplète : le texte copié semble coupé ($length caractères). '
    'Recopie-la en entier (« Tout sélectionner » avant de copier).';

/// Lit une sauvegarde sans rien modifier. Lève [BackupException] si elle est inutilisable.
Backup parseBackup(String raw) {
  final text = cleanBackupText(raw);

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    final opens = '{'.allMatches(text).length + '['.allMatches(text).length;
    final closes = '}'.allMatches(text).length + ']'.allMatches(text).length;
    if (opens > closes) throw BackupException(_truncated(text.length));
    final pos = e.offset;
    final where = pos == null
        ? ''
        : ' vers « ${text.substring(_clamp(pos - 15, text), _clamp(pos + 15, text)).replaceAll('\n', ' ').trim()} »';
    throw BackupException('Texte de sauvegarde abîmé$where.');
  }

  if (decoded is! Map) {
    throw const BackupException('Ce texte n\'est pas une sauvegarde Anneaux.');
  }
  final j = Map<String, dynamic>.from(decoded);
  if (j['sessions'] is! List || j['routine'] is! List) {
    throw const BackupException(
        'Ce texte n\'est pas une sauvegarde Anneaux (séances ou programme absents).');
  }

  final sessions = <Session>[];
  final list = j['sessions'] as List;
  for (var i = 0; i < list.length; i++) {
    try {
      sessions.add(Session.fromJson(Map<String, dynamic>.from(list[i] as Map)));
    } catch (_) {
      throw BackupException('Séance n°${i + 1} illisible dans la sauvegarde.');
    }
  }

  final routine = <ExerciseDef>[];
  for (final r in j['routine'] as List) {
    try {
      routine.add(ExerciseDef.fromJson(Map<String, dynamic>.from(r as Map)));
    } catch (_) {
      throw const BackupException('Programme illisible dans la sauvegarde.');
    }
  }

  final rest = j['restSeconds'];
  return Backup(
    sessions: sessions,
    routine: routine,
    restSeconds: rest is num ? rest.toInt() : null,
  );
}

int _clamp(int i, String s) => i < 0 ? 0 : (i > s.length ? s.length : i);
