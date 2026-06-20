/// Providers compartilhados entre telas do FênixDay
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ModoRealNotifier extends StateNotifier<bool> {
  _ModoRealNotifier() : super(true) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('fenix_modo_real') ?? true;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool('fenix_modo_real', state);
  }
}

final modoRealProvider = StateNotifierProvider<_ModoRealNotifier, bool>(
  (ref) => _ModoRealNotifier(),
);
