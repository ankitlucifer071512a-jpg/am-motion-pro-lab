import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/idea_lab_backend.dart';
import '../../services/password_recovery.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.setupMessage});

  final String? setupMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  Timer? _cooldownTimer;
  bool _creatingAccount = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  int _cooldownSeconds = 0;
  String? _message;
  bool _messageIsError = false;
  final _recovery = PasswordRecoveryService();
  final _recoveryEmail = TextEditingController();
  final _recoveryCode = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmNewPassword = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _resendTimer;
  int _recoveryStep = 0;
  int _resendSeconds = 0;
  int _resendCount = 0;
  bool _recoveryBusy = false;
  bool _showNewPassword = false;
  bool _showConfirmNewPassword = false;
  bool _recoveryVerified = false;

  @override
  void initState() {
    super.initState();
    _recovery.cleanupInterruptedRecovery();
    if (!kIsWeb) return;
    final params = <String, String>{...Uri.base.queryParameters};
    try {
      params.addAll(Uri.splitQueryString(Uri.base.fragment));
    } on FormatException {
      // Ignore normal Flutter web route fragments that are not query strings.
    }
    if (params.containsKey('error') || params.containsKey('error_code')) {
      final cancelled = params['error'] == 'access_denied' ||
          params['error_code'] == 'access_denied';
      _message = cancelled
          ? 'Sign-in was cancelled. You can try again whenever you are ready.'
          : 'Social sign-in could not be completed. Please try again.';
      _messageIsError = true;
    }
  }

  bool get _authReady => IdeaLabBackend.isReady;
  bool get _actionsEnabled => _authReady && !_busy && _cooldownSeconds == 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _password.dispose();
    _confirmPassword.dispose();
    _resendTimer?.cancel();
    _email.dispose();
    _recoveryEmail.dispose();
    _recoveryCode.dispose();
    _newPassword.dispose();
    _confirmNewPassword.dispose();
    _codeFocus.dispose();
    if (_recoveryVerified) _recovery.abandon();
    super.dispose();
  }

  Future<void> _beginRecovery() async {
    await _recovery.abandon();
    if (!mounted) return;
    setState(() {
      _recoveryStep = 1;
      _recoveryEmail.text = _email.text.trim();
      _message = null;
    });
  }

  Future<void> _sendRecoveryCode({bool resend = false}) async {
    if (_recoveryBusy || _resendSeconds > 0 ||
        (resend && _resendCount >= PasswordRecoveryRules.maximumResendsPerSession)) {
      return;
    }
    if (!PasswordRecoveryRules.isValidEmail(_recoveryEmail.text)) {
      setState(() {
        _message = 'Enter a valid email address.';
        _messageIsError = true;
      });
      return;
    }
    if (resend) _resendCount++;
    setState(() { _recoveryBusy = true; _message = null; });
    try {
      await _recovery.sendCode(_recoveryEmail.text);
      if (!mounted) return;
      setState(() {
        _recoveryStep = 2;
        _message = "If an account exists for this email, we've sent a 6-digit code.";
        _messageIsError = false;
        _resendSeconds = PasswordRecoveryRules.resendDelaySeconds;
      });
      _startResendCountdown();
      WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocus.requestFocus());
    } catch (error) {
      if (!mounted) return;
      final friendly = PasswordRecoveryService.friendlyError(error);
      PasswordRecoveryService.reportSafeAuthFailure(error, friendly);
      setState(() {
        _message = friendly;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendSeconds = PasswordRecoveryRules.nextCountdownValue(_resendSeconds));
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _verifyRecoveryCode() async {
    if (_recoveryBusy) return;
    if (!PasswordRecoveryRules.isValidCode(_recoveryCode.text)) {
      setState(() {
        _message = 'Enter the 6-digit code from your email.';
        _messageIsError = true;
      });
      return;
    }
    setState(() { _recoveryBusy = true; _message = null; });
    try {
      await _recovery.verifyCode(_recoveryEmail.text, _recoveryCode.text);
      if (!mounted) return;
      setState(() { _recoveryVerified = true; _recoveryStep = 3; _message = null; });
    } catch (error) {
      if (mounted) {
        final message = PasswordRecoveryService.friendlyError(error);
        PasswordRecoveryService.reportSafeAuthFailure(error, message);
        setState(() {
          _message = message;
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  Future<void> _saveRecoveryPassword() async {
    final password = _newPassword.text;
    if (_recoveryBusy || !PasswordRecoveryRules.isValidPassword(password) || password != _confirmNewPassword.text) return;
    setState(() { _recoveryBusy = true; _message = null; });
    try {
      await _recovery.savePassword(password);
      if (mounted) setState(() { _recoveryVerified = false; _recoveryStep = 0; _message = 'Password updated'; _messageIsError = false; });
    } catch (error) {
      if (mounted) setState(() { _message = PasswordRecoveryService.friendlyError(error); _messageIsError = true; });
    } finally {
      if (mounted) setState(() => _recoveryBusy = false);
    }
  }

  Future<void> _leaveRecovery() async {
    if (_recoveryVerified) await _recovery.abandon();
    if (!mounted) return;
    setState(() { _recoveryVerified = false; _recoveryStep = 0; _message = null; });
    _recoveryCode.clear();
  }

  Future<void> _submitEmail() async {
    if (!_actionsEnabled || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_creatingAccount) {
        final response = await IdeaLabBackend.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (response.session == null && mounted) {
          setState(() {
            _message =
                'Account created. Check your email to confirm it, then sign in.';
            _messageIsError = false;
          });
        }
      } else {
        await IdeaLabBackend.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (error) {
      _showAuthError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithProvider(
    OAuthProvider provider,
    String providerName,
  ) async {
    if (!_actionsEnabled) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final launched = await IdeaLabBackend.client.auth.signInWithOAuth(
        provider,
        // Return web builds to the current origin (including localhost dev ports).
        // Native builds use the URL scheme registered in Android/iOS project files.
        redirectTo: kIsWeb ? Uri.base.origin : 'ammotionlab://login-callback/',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        setState(() {
          _message = '$providerName sign-in did not start. Please try again.';
          _messageIsError = true;
        });
      }
    } catch (error) {
      _showAuthError(error, providerName: providerName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAuthError(Object error, {String? providerName}) {
    final code = error is AuthException ? error.code?.toLowerCase() ?? '' : '';
    final details = error is AuthException ? error.message.toLowerCase() : '';
    final combined = '$code $details';
    if ((error is AuthException && error.statusCode == '429') ||
        combined.contains('rate_limit') ||
        combined.contains('over_email_send_rate_limit') ||
        combined.contains('email rate limit') ||
        combined.contains('too many requests')) {
      PasswordRecoveryService.reportSafeAuthFailure(
        error,
        'Too many requests. Please wait before trying again.',
      );
      _startRateLimitCooldown();
      return;
    }
    final providerDisabled =
        combined.contains('provider_disabled') ||
        combined.contains('unsupported provider') ||
        combined.contains('provider is not enabled') ||
        combined.contains('provider is disabled');
    final message = providerName != null && providerDisabled
        ? '$providerName sign-in is not enabled for this Supabase project yet. Enable it in Authentication → Providers.'
        : providerDisabled
        ? 'This sign-in option is not enabled for this Supabase project. Use email sign-in or contact support.'
        : combined.contains('invalid login credentials')
        ? 'Email or password is incorrect.'
        : combined.contains('otp') || combined.contains('token') ||
                combined.contains('expired') || combined.contains('invalid code')
        ? 'That code is invalid or expired. Request a new code and try again.'
        : combined.contains('network') || combined.contains('fetch')
        ? 'No internet connection. Check your connection and try again.'
        : 'We could not complete sign-in. Check your connection and try again.';
    PasswordRecoveryService.reportSafeAuthFailure(error, message);
    if (mounted) {
      setState(() {
        _message = message;
        _messageIsError = true;
      });
    }
  }

  void _startRateLimitCooldown() {
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _cooldownSeconds = 10;
      _message = 'Please wait 10 seconds and try again.';
      _messageIsError = true;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds > 0) {
          _message = 'Please wait $_cooldownSeconds seconds and try again.';
        } else {
          _message = null;
        }
      });
      if (_cooldownSeconds == 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final setupMessage =
        widget.setupMessage ??
        (!_authReady ? IdeaLabBackend.configurationMessage : null);
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassCard(
                  strong: true,
                  padding: const EdgeInsets.fromLTRB(24, 25, 24, 22),
                  radius: 22,
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero : const Duration(milliseconds: 220),
                    child: _recoveryStep > 0
                        ? _buildRecoveryPanel()
                        : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandLogo(size: 72, full: true)),
                        const SizedBox(height: 13),
                        Text(
                          _creatingAccount
                              ? 'Create your account'
                              : 'Welcome back',
                          textAlign: TextAlign.center,
                          style: AppText.h1.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'AM MOTION LAB',
                          textAlign: TextAlign.center,
                          style: AppText.label.copyWith(letterSpacing: 2.1),
                        ),
                        if (!_creatingAccount) const SizedBox(height: 16),
                        if (setupMessage != null) ...[
                          const SizedBox(height: 18),
                          _messageBox(setupMessage, isError: true),
                        ],
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final identifier = value?.trim() ?? '';
                            if (identifier.isEmpty) {
                              return 'Enter your email.';
                            }
                            if (!PasswordRecoveryRules.isValidEmail(identifier)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: _creatingAccount
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          textInputAction: _creatingAccount
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) => _submitEmail(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) return 'Enter your password.';
                            if (_creatingAccount && password.length < 6) {
                              return 'Use at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        if (!_creatingAccount)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _beginRecovery,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        if (_creatingAccount) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPassword,
                            enabled: !_busy,
                            obscureText: _obscureConfirmPassword,
                            keyboardType: TextInputType.visiblePassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submitEmail(),
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              prefixIcon: const Icon(Icons.lock_reset_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Confirm your password.';
                              }
                              if (value != _password.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 14),
                          _messageBox(_message!, isError: _messageIsError),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _actionsEnabled ? _submitEmail : null,
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _creatingAccount
                                        ? 'Create account'
                                    : 'Sign in',
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy || _cooldownSeconds > 0
                              ? null
                              : () => setState(() {
                                  _creatingAccount = !_creatingAccount;
                                  _message = null;
                                  _formKey.currentState?.reset();
                                }),
                          child: Text(
                            _creatingAccount
                                ? 'Already have an account? Sign in'
                                : 'Create account',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(color: AppColors.glassBorder),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: AppColors.inkFaint,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: AppColors.glassBorder),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _actionsEnabled
                              ? () => _signInWithProvider(
                                  OAuthProvider.google,
                                  'Google',
                                )
                              : null,
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 26,
                          ),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _actionsEnabled
                              ? () => _signInWithProvider(
                                  OAuthProvider.facebook,
                                  'Facebook',
                                )
                              : null,
                          icon: const Icon(Icons.facebook_rounded),
                          label: const Text('Continue with Facebook'),
                        ),
                        if (_cooldownSeconds > 0) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Try again in $_cooldownSeconds seconds.',
                            textAlign: TextAlign.center,
                            style: AppText.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryPanel() {
    final title = switch (_recoveryStep) {
      1 => 'Reset your password',
      2 => 'Check your email',
      _ => 'Choose a new password',
    };
    final newPassword = _newPassword.text;
    final strength = (newPassword.length / 12).clamp(0.0, 1.0);
    return Column(
      key: ValueKey(_recoveryStep),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/brand/am-motion-icon.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            semanticLabel: 'AM MOTION LAB logo',
          ),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: AppText.h1.copyWith(fontSize: 23)),
        const SizedBox(height: 18),
        if (_recoveryStep == 1) ...[
          TextField(
              controller: _recoveryEmail,
              enabled: !_recoveryBusy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendRecoveryCode(),
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
            ),
          const SizedBox(height: 12),
          Text('Signed up with Google or Facebook? Use that button to sign in.', textAlign: TextAlign.center, style: AppText.caption),
          const SizedBox(height: 14),
          _recoveryButton('Send code', _sendRecoveryCode),
        ] else if (_recoveryStep == 2) ...[
          Text(
            PasswordRecoveryRules.maskEmail(_recoveryEmail.text),
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 5),
          Text(
            'Enter the 6-digit code from your email.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
          const SizedBox(height: 14),
          Semantics(
            label: '6-digit recovery code',
            child: SizedBox(
              height: 58,
              child: Stack(
                children: [
                  Row(
                    children: List.generate(6, (index) {
                      final code = _recoveryCode.text;
                      final focused = code.length == index;
                      return Expanded(
                        child: Container(
                          height: 54,
                          margin: EdgeInsets.only(right: index == 5 ? 0 : 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.navyDeep.withValues(alpha: .36),
                            border: Border.all(color: focused ? AppColors.blue : AppColors.glassBorder, width: focused ? 1.5 : 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(index < code.length ? code[index] : '', style: AppText.h1.copyWith(fontSize: 21)),
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: _recoveryCode,
                    focusNode: _codeFocus,
                    enabled: !_recoveryBusy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits != value) { _recoveryCode.value = TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length)); }
                      setState(() {});
                      if (digits.length == 6) _verifyRecoveryCode();
                    },
                    onSubmitted: (_) => _verifyRecoveryCode(),
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, contentPadding: EdgeInsets.zero),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _recoveryButton('Verify', _verifyRecoveryCode),
          TextButton(
            onPressed: _recoveryBusy ? null : _leaveRecovery,
            child: const Text('Change email'),
          ),
          TextButton(
            onPressed: _recoveryBusy || _resendSeconds > 0 || _resendCount >= PasswordRecoveryRules.maximumResendsPerSession ? null : () => _sendRecoveryCode(resend: true),
            child: Text(_resendSeconds > 0 ? 'Resend code in $_resendSeconds s' : _resendCount >= PasswordRecoveryRules.maximumResendsPerSession ? 'Resend limit reached' : 'Resend code'),
          ),
        ] else ...[
          TextField(
            controller: _newPassword,
            obscureText: !_showNewPassword,
            enabled: !_recoveryBusy,
            autofillHints: const [AutofillHints.newPassword],
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'New password', suffixIcon: IconButton(tooltip: _showNewPassword ? 'Hide password' : 'Show password', onPressed: () => setState(() => _showNewPassword = !_showNewPassword), icon: Icon(_showNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmNewPassword,
            obscureText: !_showConfirmNewPassword,
            enabled: !_recoveryBusy,
            autofillHints: const [AutofillHints.newPassword],
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _saveRecoveryPassword(),
            decoration: InputDecoration(labelText: 'Confirm password', suffixIcon: IconButton(tooltip: _showConfirmNewPassword ? 'Hide password' : 'Show password', onPressed: () => setState(() => _showConfirmNewPassword = !_showConfirmNewPassword), icon: Icon(_showConfirmNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
          ),
          const SizedBox(height: 12),
          Row(children: [Icon(PasswordRecoveryRules.isValidPassword(newPassword) ? Icons.check_circle : Icons.circle_outlined, size: 17), const SizedBox(width: 8), Text('At least ${PasswordRecoveryRules.minimumLength} characters', style: AppText.caption)]),
          const SizedBox(height: 7),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: strength, minHeight: 6, color: strength < .4 ? AppColors.violet : AppColors.blue, backgroundColor: AppColors.glassBorder)),
          const SizedBox(height: 14),
          _recoveryButton('Save password', _saveRecoveryPassword, enabled: PasswordRecoveryRules.isValidPassword(newPassword) && newPassword == _confirmNewPassword.text),
        ],
        if (_message != null) ...[
          const SizedBox(height: 14),
          _messageBox(_message!, isError: _messageIsError),
        ],
        const SizedBox(height: 10),
        TextButton(onPressed: _recoveryBusy ? null : _leaveRecovery, child: const Text('Back to sign in')),
      ],
    );
  }

  Widget _recoveryButton(String label, VoidCallback action, {bool enabled = true}) => SizedBox(
    height: 50,
    child: FilledButton(onPressed: _recoveryBusy || !enabled ? null : action, child: _recoveryBusy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label)),
  );

  Widget _messageBox(String text, {required bool isError}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (isError ? AppColors.violet : AppColors.blue).withValues(
        alpha: 0.13,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Text(
      text,
      style: AppText.body.copyWith(
        color: isError ? AppColors.ink : AppColors.sky,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
