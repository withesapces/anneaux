# Anneaux

Carnet d'entraînement aux anneaux (Android, Flutter).

## Ce que fait l'app

- **Séance guidée** : un exercice à la fois, une série à la fois. Chaque série est pré-remplie avec ce que tu as fait la dernière fois au même rang (reps + hauteur de sangle). Tu ajustes avec − / + (ou en touchant le chiffre) puis « Valider la série ».
- **Repos de 2 min** automatique après chaque série, avec bouton **« Passer le repos »**, ± 30 s, bips sur les 3 dernières secondes et triple bip + vibration à la fin. Ta musique baisse un instant au lieu d'être coupée.
- **Chrono** pour les exercices en secondes (Planche, Tenir), avec bip quand l'objectif est atteint.
- L'écran reste allumé pendant la séance. La séance en cours est sauvegardée à chaque série : si l'app se ferme, tu reprends où tu en étais.
- **Historique** pré-rempli avec tes séances du 25 août au 20 octobre 2026. Chaque séance se copie au même format que tes notes (`Pull ups : 2x10 + 1x7 (hauteur 5)`).
- **Progression** : total de reps/secondes par séance, par exercice, avec courbe.
- **Programme** modifiable : ordre, hauteurs, reps ou secondes, « de chaque côté », durée du repos.
- **Sauvegarde** : export/import en texte via le presse-papiers.

Le nombre de séries visé pour chaque exercice = le nombre de séries faites la dernière fois. Une fois atteint, l'app passe à l'exercice suivant (tu peux revenir en arrière pour une série bonus).

## Installer sur le téléphone

Chaque push sur `main` compile l'APK automatiquement (onglet **Actions**). Une fois le build vert :

1. Sur le téléphone, ouvre la page **Releases** du dépôt → « Dernière version » → `app-release.apk`.
2. Autorise l'installation depuis le navigateur si Android le demande.

Les builds sont signés avec la même clé (`ci/debug.keystore`), donc une nouvelle version s'installe par-dessus l'ancienne sans perdre les données.

## Développer en local

```bash
flutter create . --platforms=android --org fr.webeedigital --project-name anneaux
rm -f test/widget_test.dart
flutter run
```

Le dossier `android/` n'est pas versionné : il est régénéré par `flutter create`.
