import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/art.dart';
import 'widgets/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const AnneauxApp());
}

/// Affiche l'app immédiatement, charge les données ensuite.
/// Si le chargement échoue, l'erreur s'affiche au lieu de rester bloqué sur le logo.
class AnneauxApp extends StatefulWidget {
  const AnneauxApp({super.key});

  @override
  State<AnneauxApp> createState() => _AnneauxAppState();
}

class _AnneauxAppState extends State<AnneauxApp> {
  AppStore? _store;
  Object? _error;
  StackTrace? _stack;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _stack = null;
    });
    try {
      final store = AppStore();
      await store.load().timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _store = store);
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _error = e;
          _stack = st;
        });
      }
    }
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await confirmDialog(context, 'Tout réinitialiser ?',
        'Toutes les séances enregistrées sur ce téléphone seront effacées. '
            'Copie l\'erreur et tente « Réessayer » d\'abord.',
        yes: 'Réinitialiser', danger: true);
    if (!ok) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.clear();
    } catch (_) {}
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return StoreScope(
        store: store,
        child: MaterialApp(
          title: 'Anneaux',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: const HomeShell(),
        ),
      );
    }
    return MaterialApp(
      title: 'Anneaux',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: Scaffold(
        body: SafeArea(
          child: _error == null
              ? const Center(child: AnneauxLogo(size: 96))
              : Builder(
                  builder: (context) => ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const D('Erreur au démarrage', size: 40, w: FontWeight.w900),
                      const SizedBox(height: 12),
                      SelectableText('$_error\n\n$_stack', style: body(13, color: C.muted)),
                      const SizedBox(height: 16),
                      BigButton('Réessayer', height: 72, fontSize: 30, onTap: _load),
                      const SizedBox(height: 8),
                      LinkButton('Copier l\'erreur',
                          onTap: () => Clipboard.setData(
                              ClipboardData(text: '$_error\n\n$_stack'))),
                      LinkButton('Réinitialiser les données', onTap: () => _reset(context)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
