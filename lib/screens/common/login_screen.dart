import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _staff = false;
  bool _busy = false;
  bool _hide = true;
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _secret = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (_staff) {
        await AuthService.signInStaff(_id.text, _secret.text);
      } else {
        await AuthService.signInStudent(_id.text, _secret.text);
      }
      // AuthGate takes over from here.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Friendly header illustration
              Container(
                height: 210,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: _blob(140, Colors.white.withValues(alpha: 0.08)),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -40,
                    child: _blob(120, AppColors.amber.withValues(alpha: 0.25)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.spa_rounded, color: Colors.white, size: 30),
                      ),
                      const Spacer(),
                      Text(AppConfig.schoolShort,
                          style: t.labelLarge?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('A safe place\nto talk.',
                          style: t.headlineSmall?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 26),
              Text('Welcome 👋', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Log in to the Guidance & Counselling unit',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Student'), icon: Icon(Icons.backpack_rounded)),
                  ButtonSegment(value: true, label: Text('Counsellor'), icon: Icon(Icons.badge_rounded)),
                ],
                selected: {_staff},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _staff = s.first;
                  _id.clear();
                  _secret.clear();
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('login-id'),
                controller: _id,
                keyboardType: _staff ? TextInputType.emailAddress : TextInputType.text,
                textCapitalization: _staff ? TextCapitalization.none : TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: _staff
                    ? inputDeco('Email', icon: Icons.alternate_email_rounded)
                    : inputDeco('Admission number', icon: Icons.badge_outlined, hint: 'e.g. GSSUS/2024/015'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('login-secret'),
                controller: _secret,
                obscureText: _hide,
                keyboardType: _staff ? TextInputType.visiblePassword : TextInputType.number,
                inputFormatters: _staff
                    ? null
                    : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onFieldSubmitted: (_) => _submit(),
                decoration: inputDeco(_staff ? 'Password' : '6-digit PIN', icon: Icons.lock_outline_rounded)
                    .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!_staff && v.length != 6) return 'PIN has 6 digits';
                  return null;
                },
              ),
              const SizedBox(height: 22),
              FilledButton(
                key: const ValueKey('login-button'),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Log in'),
              ),
              const SizedBox(height: 18),
              SoftCard(
                color: AppColors.amberSoft,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _staff
                          ? 'Staff accounts are created by the school admin.'
                          : 'No PIN yet, or forgot it? Visit the Guidance & Counselling office.',
                      style: t.bodySmall?.copyWith(color: AppColors.ink),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _blob(double s, Color c) =>
      Container(width: s, height: s, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
