import 'package:flutter/material.dart';

import '../../config.dart';
import '../../main.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/account_sheet.dart';
import '../common/careers_screen.dart';

/// Student profile: school details (read-only, set by the school),
/// preferred stream and career interests (editable), saved careers.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Profile _me = Me.of(context);
  late String _stream = _me.preferredStream ?? 'undecided';
  late final _interests = TextEditingController(text: _me.careerInterests);
  List<Career> _saved = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final r = await Future.wait([Api.careers(), Api.mySavedCareerIds()]);
      final all = r[0] as List<Career>;
      final ids = r[1] as Set<int>;
      if (mounted) setState(() => _saved = all.where((c) => ids.contains(c.id)).toList());
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Api.updateMyProfile(stream: _stream, interests: _interests.text);
      await Me.reload();
      if (!mounted) return;
      setState(() => _me = Me.of(context));
      showSnack(context, 'Profile saved');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
        SoftCard(
          child: Row(children: [
            InitialsAvatar(_me.fullName, size: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_me.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text([_me.admissionNo, _me.className].whereType<String>().join(' · '),
                    style: const TextStyle(color: AppColors.muted)),
                const Text(AppConfig.schoolShort, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        const Text('Name, admission number and class are kept by the school. Ask the counsellor to correct them.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SectionTitle('My career plans'),
        DropdownButtonFormField<String>(
          key: const ValueKey('stream-dropdown'),
          initialValue: _stream,
          decoration: inputDeco('Stream I prefer', icon: Icons.category_outlined),
          items: [
            for (final s in streams) DropdownMenuItem(value: s.key, child: Text(s.label)),
            const DropdownMenuItem(value: 'undecided', child: Text('Not decided yet')),
          ],
          onChanged: (v) => setState(() => _stream = v ?? 'undecided'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('interests-field'),
          controller: _interests,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: inputDeco('What do you enjoy or want to become?',
              hint: 'e.g. I like Biology and helping people. I want to be a nurse or doctor.'),
        ),
        FilledButton(
          key: const ValueKey('save-profile'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
        const SizedBox(height: 6),
        const Text('The counsellor can see these when you start a named (not anonymous) chat.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        SectionTitle('Saved careers (${_saved.length})'),
        if (_saved.isEmpty)
          const Text('Tap the heart on any career in Explore careers to save it here.',
              style: TextStyle(color: AppColors.muted))
        else
          for (final c in _saved)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () async {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => CareerDetailScreen(career: c, saved: true,
                          onToggleSave: () => Api.unsaveCareer(c.id))));
                  _loadSaved();
                },
                child: Row(children: [
                  Icon(streamFor(c.stream).icon, color: streamFor(c.stream).color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ]),
              ),
            ),
        const SectionTitle('Account'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password_rounded),
          title: const Text('Change PIN'),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ChangeSecretScreen(isStaff: false))),
        ),
        ListTile(
          key: const ValueKey('logout'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
          title: const Text('Log out', style: TextStyle(color: AppColors.danger)),
          onTap: () async {
            Navigator.pop(context);
            await AuthService.signOut();
          },
        ),
      ]),
    );
  }
}
