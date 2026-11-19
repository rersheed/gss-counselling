import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late Future<List<Profile>> _future = Api.students();
  String _q = '';

  Future<void> _reload() async {
    final f = Api.students();
    setState(() { _future = f; });
    await f.catchError((_) => <Profile>[]);
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  Future<void> _actions(Profile s) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: InitialsAvatar(s.fullName),
            title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([s.admissionNo, s.className].whereType<String>().join(' · ')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.pin_rounded),
            title: const Text('Reset PIN'),
            subtitle: const Text('Creates a new 6-digit PIN'),
            onTap: () async {
              Navigator.pop(sheet);
              try {
                final r = await Api.manageUsers({'action': 'reset_pin', 'user_id': s.id});
                if (mounted) {
                  showPinDialog(context, name: s.fullName, admissionNo: s.admissionNo ?? '', pin: r['pin'] as String);
                }
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
          ),
          ListTile(
            leading: Icon(s.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                color: s.isActive ? AppColors.danger : AppColors.primary),
            title: Text(s.isActive ? 'Disable account' : 'Enable account'),
            subtitle: Text(s.isActive ? 'e.g. student has left the school' : 'Allow this student to log in again'),
            onTap: () async {
              Navigator.pop(sheet);
              try {
                await Api.manageUsers({'action': 'set_active', 'user_id': s.id, 'active': !s.isActive});
                _reload();
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(
            tooltip: 'Add many students',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => _open(const BulkAddStudentsScreen()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _open(const AddStudentScreen()),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add student'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: inputDeco('Search name, admission no or class', icon: Icons.search_rounded),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Profile>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorRetry(snap.error!, _reload);
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!
                  .where((s) =>
                      _q.isEmpty ||
                      s.fullName.toLowerCase().contains(_q) ||
                      (s.admissionNo ?? '').toLowerCase().contains(_q) ||
                      (s.className ?? '').toLowerCase().contains(_q))
                  .toList();
              if (snap.data!.isEmpty) {
                return const EmptyState(
                  icon: Icons.groups_rounded,
                  title: 'No students yet',
                  message: 'Add students one by one, or paste a whole class list with the button at the top.',
                );
              }
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return SoftCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onTap: () => _actions(s),
                      child: Row(children: [
                        InitialsAvatar(s.fullName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text([s.admissionNo, s.className].whereType<String>().join(' · '),
                                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ]),
                        ),
                        if (!s.isActive)
                          const Pill('Disabled', color: AppColors.danger, bg: AppColors.dangerSoft),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});
  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _adm = TextEditingController();
  final _cls = TextEditingController();
  final _pin = TextEditingController();
  String? _gender;
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final r = await Api.manageUsers({
        'action': 'create_student',
        'full_name': _name.text.trim(),
        'admission_no': _adm.text.trim(),
        'class_name': _cls.text.trim(),
        'gender': _gender,
        if (_pin.text.isNotEmpty) 'pin': _pin.text,
      });
      if (!mounted) return;
      await showPinDialog(context,
          name: r['full_name'] as String, admissionNo: r['admission_no'] as String, pin: r['pin'] as String);
      if (!mounted) return;
      // Ready for the next student in the same class
      _name.clear();
      _adm.clear();
      _pin.clear();
      setState(() => _gender = null);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add student')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(18), children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: inputDeco('Full name', icon: Icons.person_outline_rounded),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Enter the full name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adm,
              textCapitalization: TextCapitalization.characters,
              decoration: inputDeco('Admission number', icon: Icons.badge_outlined, hint: 'GSSUS/2024/015'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cls,
              textCapitalization: TextCapitalization.characters,
              decoration: inputDeco('Class', icon: Icons.class_outlined, hint: 'SS2 A'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'female', label: Text('Female')),
              ],
              emptySelectionAllowed: true,
              selected: {if (_gender != null) _gender!},
              onSelectionChanged: (s) => setState(() => _gender = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: inputDeco('PIN (optional)',
                  icon: Icons.pin_outlined, helper: 'Leave empty to generate a random 6-digit PIN.'),
              validator: (v) => (v != null && v.isNotEmpty && v.length != 6) ? 'PIN must be 6 digits' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Creating…' : 'Create account')),
          ]),
        ),
      );
}

/// Paste a class list: one student per line — "Full name, Admission no, Class".
class BulkAddStudentsScreen extends StatefulWidget {
  const BulkAddStudentsScreen({super.key});
  @override
  State<BulkAddStudentsScreen> createState() => _BulkAddStudentsScreenState();
}

class _BulkAddStudentsScreenState extends State<BulkAddStudentsScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>>? _created;
  List<Map<String, dynamic>>? _failed;

  List<Map<String, String>> _parse() {
    final out = <Map<String, String>>[];
    for (final line in _text.text.split('\n')) {
      final parts = line.split(RegExp(r'[,\t;]')).map((p) => p.trim()).toList();
      if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) continue;
      out.add({
        'full_name': parts[0],
        'admission_no': parts[1],
        if (parts.length > 2 && parts[2].isNotEmpty) 'class_name': parts[2],
        if (parts.length > 3 && parts[3].isNotEmpty)
          'gender': parts[3].toLowerCase().startsWith('f') ? 'female' : 'male',
      });
    }
    return out;
  }

  Future<void> _go() async {
    final students = _parse();
    if (students.isEmpty) {
      showSnack(context, 'No valid lines. Use: Full name, Admission no, Class', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.manageUsers({'action': 'bulk_create_students', 'students': students});
      if (!mounted) return;
      setState(() {
        _created = List<Map<String, dynamic>>.from(r['created'] as List);
        _failed = List<Map<String, dynamic>>.from(r['failed'] as List);
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _sheet => [
        'Name\tAdmission No\tPIN',
        for (final c in _created ?? const <Map<String, dynamic>>[])
          '${c['full_name']}\t${c['admission_no']}\t${c['pin']}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    if (_created != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts created')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          SoftCard(
            color: AppColors.mint,
            child: Text(
                '${_created!.length} created${_failed!.isEmpty ? '' : ', ${_failed!.length} failed'}. '
                'Copy this list now — PINs are not shown again (you can reset them later).',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _sheet));
              showSnack(context, 'Copied — paste into Excel, Google Sheets or WhatsApp');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy list with PINs'),
          ),
          const SizedBox(height: 12),
          for (final c in _created!)
            ListTile(
              dense: true,
              title: Text(c['full_name'] as String),
              subtitle: Text(c['admission_no'] as String),
              trailing: Text(c['pin'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 16)),
            ),
          if (_failed!.isNotEmpty) ...[
            const SectionTitle('Not created'),
            for (final f in _failed!)
              ListTile(
                dense: true,
                leading: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                title: Text('${f['full_name']} (${f['admission_no']})'),
                subtitle: Text('${f['error']}'),
              ),
          ],
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Add many students')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Paste one student per line:', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Full name, Admission no, Class, Gender\n'
            'e.g.  Aisha Bello, GSSUS/2024/015, SS2 A, F',
            style: TextStyle(color: AppColors.muted, fontFamily: 'monospace', fontSize: 12.5)),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 10,
          maxLines: 20,
          decoration: inputDeco('Class list'),
        ),
        const SizedBox(height: 8),
        const Text('You can copy columns straight from Excel. A random PIN is made for each student. Max 300 at a time.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _go,
          child: Text(_busy ? 'Creating accounts… please wait' : 'Create accounts'),
        ),
      ]),
    );
  }
}
