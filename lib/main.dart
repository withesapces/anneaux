import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnneauxApp());
}

ThemeData _theme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE8833A),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

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

  Future<void> _reset() async {
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
          theme: _theme(),
          home: const HomeShell(),
        ),
      );
    }
    return MaterialApp(
      title: 'Anneaux',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: Scaffold(
        body: SafeArea(
          child: _error == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Erreur au démarrage',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SelectableText('$_error\n\n$_stack'),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Réessayer')),
                    TextButton(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: '$_error\n\n$_stack')),
                      child: const Text('Copier l\'erreur'),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Réinitialiser les données'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
