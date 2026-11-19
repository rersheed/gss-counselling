import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';
import '../common/help_now_screen.dart';
import 'new_case_screen.dart';
import 'profile_screen.dart';

class StudentHome extends StatefulWidget {
  final void Function(int tab) onGoTab;
  const StudentHome({super.key, required this.onGoTab});
  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int? _mood;
  List<CaseItem> _cases = [];
  Appointment? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.todaysMood(), Api.myCases(), Api.myAppointments()]);
      if (!mounted) return;
      final appts = (r[2] as List<Appointment>)
          .where((a) => a.isUpcoming && (a.status == 'confirmed' || a.status == 'requested'))
          .toList()
        ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
      setState(() {
        _mood = r[0] as int?;
        _cases = r[1] as List<CaseItem>;
        _next = appts.isEmpty ? null : appts.first;
      });
    } catch (_) {
      // Home stays usable offline; individual tabs show errors.
    }
  }

  Future<void> _pickMood(Mood m) async {
    setState(() => _mood = m.value);
    try {
      await Api.logMood(m.value);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _openNew([String? topic]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NewCaseScreen(topic: topic)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = Me.of(context);
    final t = Theme.of(context).textTheme;
    final mood = _mood == null ? null : moods.firstWhere((m) => m.value == _mood);
    final unread = _cases.where((c) => c.unread).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.zero, children: [
        // ---------- Header ----------
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sannu, ${me.firstName} 👋',
                      style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('How are you feeling today?', style: t.bodyMedium?.copyWith(color: Colors.white70)),
                ]),
              ),
              GestureDetector(
                key: const ValueKey('profile-button'),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: InitialsAvatar(me.fullName, size: 42),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (final m in moods)
                GestureDetector(
                  onTap: () => _pickMood(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _mood == m.value ? Colors.white : Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(m.label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _mood == m.value ? AppColors.primaryDark : Colors.white,
                          )),
                    ]),
                  ),
                ),
            ]),
            if (mood != null) ...[
              const SizedBox(height: 14),
              Text(mood.reply, style: t.bodySmall?.copyWith(color: Colors.white, height: 1.35)),
            ],
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ---------- Talk to a counsellor ----------
            SoftCard(
              onTap: () => _openNew(),
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Talk to a counsellor',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Private. You can even stay anonymous.',
                        style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    const Pill('Start a chat', icon: Icons.add_rounded, color: Colors.white, bg: AppColors.primary),
                  ]),
                ),
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                  child: const Icon(Icons.forum_rounded, size: 36, color: AppColors.primary),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.sos_rounded,
                  label: 'I need help now',
                  color: AppColors.danger,
                  bg: AppColors.dangerSoft,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpNowScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickTile(
                  icon: Icons.event_available_rounded,
                  label: 'Book a session',
                  color: AppColors.sky,
                  bg: AppColors.skySoft,
                  onTap: () => widget.onGoTab(3),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SoftCard(
              key: const ValueKey('explore-careers'),
              onTap: () => widget.onGoTab(2),
              color: AppColors.amberSoft,
              child: Row(children: [
                const Icon(Icons.work_rounded, color: AppColors.amber, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Explore careers',
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                    Text(
                      me.preferredStream == null || me.preferredStream == 'undecided'
                          ? 'See jobs by Science, Arts, Commercial and Technical streams'
                          : 'Careers for the ${streamFor(me.preferredStream).label} stream and more',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.amber),
              ]),
            ),

            // ---------- Next appointment ----------
            if (_next != null) ...[
              const SectionTitle('Your next session'),
              SoftCard(
                onTap: () => widget.onGoTab(3),
                child: Row(children: [
                  Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      Text('${_next!.slotStart.day}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.amber)),
                      Text(_month(_next!.slotStart.month),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.amber)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(niceDate(_next!.slotStart), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_next!.counsellorName ?? 'Guidance & Counselling office',
                          style: const TextStyle(color: AppColors.muted)),
                    ]),
                  ),
                  StatusPill(_next!.status),
                ]),
              ),
            ],

            // ---------- Topics ----------
            const SectionTitle('What would you like to talk about?'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final tp in topics)
                ActionChip(
                  avatar: Icon(tp.icon, size: 18, color: tp.color),
                  label: Text(tp.label),
                  backgroundColor: tp.soft,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink),
                  onPressed: () => _openNew(tp.key),
                ),
            ]),

            // ---------- Recent chats ----------
            if (_cases.isNotEmpty) ...[
              SectionTitle(
                unread > 0 ? 'Recent chats · $unread new' : 'Recent chats',
                trailing: TextButton(onPressed: () => widget.onGoTab(1), child: const Text('See all')),
              ),
              for (final c in _cases.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CaseTile(c, onChanged: _load),
                ),
            ],
          ]),
        ),
      ]),
    );
  }

  String _month(int m) =>
      const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][m - 1];
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: onTap,
        color: bg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 14),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

/// A row in the student's chat list.
class CaseTile extends StatelessWidget {
  final CaseItem c;
  final VoidCallback onChanged;
  const CaseTile(this.c, {super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                caseId: c.id,
                title: c.subject,
                topic: c.topic,
                status: c.status,
                isAnonymous: c.isAnonymous,
                isUrgent: c.isUrgent,
              ),
            ),
          );
          onChanged();
        },
        child: Row(children: [
          TopicIcon(c.topic),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(c.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: c.unread ? FontWeight.w800 : FontWeight.w700)),
                ),
                Text(timeAgo(c.lastMessageAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(
                  child: Text(
                    (c.lastSenderRole == 'staff' ? 'Counsellor: ' : 'You: ') + (c.lastMessagePreview ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.unread ? AppColors.ink : AppColors.muted,
                      fontWeight: c.unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (c.unread)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                StatusPill(c.status),
                if (c.isAnonymous)
                  const Pill('Anonymous', icon: Icons.visibility_off_rounded, color: AppColors.lilac, bg: AppColors.lilacSoft),
                if (c.isUrgent && c.status != 'closed')
                  const Pill('Urgent', color: AppColors.danger, bg: AppColors.dangerSoft),
              ]),
            ]),
          ),
        ]),
      );
}
