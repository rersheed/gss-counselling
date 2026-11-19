import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Admin only: create a counsellor (or another admin) login.
class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});
  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _role = 'counsellor';
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.manageUsers({
        'action': 'create_staff',
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'password': _password.text,
        'role': _role,
      });
      if (!mounted) return;
      showSnack(context, '${_name.text.trim()} can now log in with ${_email.text.trim()}');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add staff')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(18), children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'counsellor', label: Text('Counsellor')),
                ButtonSegment(value: 'admin', label: Text('Admin')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _role == 'admin'
                  ? 'Admins can do everything counsellors can, add staff, and reveal anonymous identities for safeguarding.'
                  : 'Counsellors reply to students, manage sessions and add student accounts.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: inputDeco('Full name (as students will see it)', icon: Icons.person_outline_rounded,
                  hint: 'Mrs Hauwa Sani'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: inputDeco('Email', icon: Icons.alternate_email_rounded),
              validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: inputDeco('Phone (optional)', icon: Icons.phone_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: inputDeco('Temporary password', icon: Icons.lock_outline_rounded,
                  helper: 'At least 8 characters. They can change it after logging in.'),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Creating…' : 'Create login')),
          ]),
        ),
      );
}
