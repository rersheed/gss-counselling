import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Bottom sheet with the user's details, change PIN/password and log out.
Future<void> showAccountSheet(BuildContext context, Profile me, {List<Widget> extra = const []}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InitialsAvatar(me.fullName, size: 64),
          const SizedBox(height: 10),
          Text(me.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            me.isStaff
                ? (me.isAdmin ? 'Admin' : 'Counsellor')
                : [me.admissionNo, me.className].whereType<String>().join(' · '),
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          const Text(AppConfig.schoolShort, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 16),
          ...extra,
          ListTile(
            leading: const Icon(Icons.password_rounded),
            title: Text(me.isStaff ? 'Change password' : 'Change PIN'),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeSecretScreen(isStaff: me.isStaff)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Log out', style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await AuthService.signOut();
            },
          ),
        ]),
      ),
    ),
  );
}

class ChangeSecretScreen extends StatefulWidget {
  final bool isStaff;
  const ChangeSecretScreen({super.key, required this.isStaff});
  @override
  State<ChangeSecretScreen> createState() => _ChangeSecretScreenState();
}

class _ChangeSecretScreenState extends State<ChangeSecretScreen> {
  final _form = GlobalKey<FormState>();
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _busy = false;

  String get _word => widget.isStaff ? 'password' : 'PIN';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.changePassword(_a.text);
      if (!mounted) return;
      showSnack(context, 'Your $_word has been changed');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.isStaff
        ? null
        : [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];
    return Scaffold(
      appBar: AppBar(title: Text('Change $_word')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _a,
            obscureText: true,
            keyboardType: widget.isStaff ? TextInputType.visiblePassword : TextInputType.number,
            inputFormatters: digits,
            decoration: inputDeco('New $_word', icon: Icons.lock_outline_rounded),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!widget.isStaff && !RegExp(r'^\d{6}$').hasMatch(v)) return 'PIN must be 6 digits';
              if (widget.isStaff && v.length < 8) return 'At least 8 characters';
              if (!widget.isStaff && RegExp(r'^(\d)\1{5}$').hasMatch(v)) return 'Too easy to guess';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _b,
            obscureText: true,
            keyboardType: widget.isStaff ? TextInputType.visiblePassword : TextInputType.number,
            inputFormatters: digits,
            decoration: inputDeco('Type it again', icon: Icons.lock_outline_rounded),
            validator: (v) => v != _a.text ? 'Does not match' : null,
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
          if (!widget.isStaff) ...[
            const SizedBox(height: 14),
            const Text('Keep your PIN secret. Do not share it with friends.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ],
        ]),
      ),
    );
  }
}
