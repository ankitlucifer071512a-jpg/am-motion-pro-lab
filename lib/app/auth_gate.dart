import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/login_screen.dart';
import '../services/idea_lab_backend.dart';
import '../services/password_recovery.dart';
import 'shell.dart';

class AppAuthGate extends StatefulWidget {
  const AppAuthGate({super.key, this.initialization});

  final Future<void>? initialization;

  @override
  State<AppAuthGate> createState() => _AppAuthGateState();
}

class _AppAuthGateState extends State<AppAuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;

  @override
  void initState() {
    super.initState();
    PasswordRecoveryService.recoveryInProgress.addListener(_handleRecoveryState);
    widget.initialization?.then((_) {
      if (mounted) _prepareAuth();
    }).catchError((_) {
      if (mounted) setState(() {});
    });
    if (widget.initialization == null) _prepareAuth();
  }

  Future<void> _prepareAuth() async {
    if (!IdeaLabBackend.isReady) return;
    await PasswordRecoveryService().cleanupInterruptedRecovery();
    if (!mounted) return;
    setState(_attachAuth);
  }

  void _attachAuth() {
    if (!IdeaLabBackend.isReady) return;
    if (_authSubscription != null) return;
    final auth = IdeaLabBackend.client.auth;
    _user = auth.currentUser;
    _authSubscription = auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (PasswordRecoveryService.isRecoveryInProgress) return;
      setState(() => _user = state.session?.user);
    });
  }

  void _handleRecoveryState() {
    if (!mounted || PasswordRecoveryService.isRecoveryInProgress ||
        !IdeaLabBackend.isReady) {
      return;
    }
    setState(() => _user = IdeaLabBackend.client.auth.currentUser);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    PasswordRecoveryService.recoveryInProgress.removeListener(_handleRecoveryState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!IdeaLabBackend.isReady) {
      return LoginScreen(
        setupMessage: IdeaLabBackend.isConfigured
            ? IdeaLabBackend.initializationError ??
                'Supabase is not ready yet. Check the local project configuration.'
            : IdeaLabBackend.configurationMessage,
      );
    }
    return _user == null ? const LoginScreen() : const AppShell();
  }
}
