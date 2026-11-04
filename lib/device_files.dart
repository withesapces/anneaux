import 'package:flutter/services.dart';

/// Accès aux fichiers du téléphone (code natif dans MainActivity, injecté par ci/patch_android.py).
class DeviceFiles {
  static const _ch = MethodChannel('anneaux/files');

  /// Dossier visible dans « Mes fichiers », conservé si l'app est désinstallée.
  static const folderLabel = 'Téléchargements/Anneaux';

  /// Écrit (ou remplace) un fichier texte dans Téléchargements/Anneaux.
  static Future<void> save(String name, String text) =>
      _ch.invokeMethod<String>('save', {'name': name, 'text': text});

  /// Ouvre le sélecteur de fichiers Android. Renvoie le texte, ou null si annulé.
  static Future<String?> open() => _ch.invokeMethod<String>('open');
}
