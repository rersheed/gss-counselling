import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';
import 'screens/common/login_screen.dart';
import 'screens/counsellor/counsellor_shell.dart';
import 'screens/student/student_shell.dart';
import 'services/api.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  runApp(const CounsellingApp());
}

class CounsellingApp extends StatelessWidget {
  const CounsellingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      );
}

/// Holds the signed-in user's profile so every screen (including pushed
/// routes, which sit outside AuthGate in the widget tree) can read it.
class Me {
  static Profile? _current;
  static Profile of(BuildContext context) => _current!;

  /// Refresh after the user edits their own profile.
  static Future<void> reload() async {
    final p = await AuthService.loadMyProfile();
    if (p != null) _current = p;
  }
}

/// Decides which screen to show: login, student app or counsellor app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  Profile? _profile;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _sub = db.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn ||
          s.event == AuthChangeEvent.signedOut ||
          s.event == AuthChangeEvent.initialSession) {
        if (s.event == AuthChangeEvent.signedOut && mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (db.auth.currentSession == null) {
      if (mounted) setState(() { _profile = null; _loading = false; _error = null; });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final p = await AuthService.loadMyProfile();
      if (p == null || !p.isActive) {
        await AuthService.signOut();
        if (mounted) {
          showSnack(context, 'This account is not set up yet or has been disabled. Please see the counsellor.',
              error: true);
        }
        return;
      }
      Me._current = p;
      if (mounted) setState(() { _profile = p; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: ErrorRetry(_error!, _load));
    }
    final p = _profile;
    if (p == null || db.auth.currentSession == null) return const LoginScreen();
    return p.isStaff ? const CounsellorShell() : const StudentShell();
  }
}
