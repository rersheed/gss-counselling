import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/account_sheet.dart';
import 'add_staff_screen.dart';
import 'inbox_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tab) onGoTab;
  const DashboardScreen({super.key, required this.onGoTab});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  List<InboxItem> _urgent = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.staffStats(), Api.inbox()]);
      if (!mounted) return;
      setState(() {
        _stats = r[0] as Map<String, dynamic>;
        _urgent = (r[1] as List<InboxItem>).where((c) => c.isUrgent && c.status != 'closed').take(5).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  int _n(String k) => (_stats?[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final me = Me.of(context);
    final t = Theme.of(context).textTheme;
    if (_error != null && _stats == null) return Scaffold(body: ErrorRetry(_error!, _load));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: EdgeInsets.zero, children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sannu, ${me.firstName}',
                      style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    _n('urgent') > 0
                        ? '${_n('urgent')} urgent ${_n('urgent') == 1 ? 'case needs' : 'cases need'} you'
                        : 'No urgent cases right now',
                    style: t.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: () => showAccountSheet(context, me, extra: [
                  if (me.isAdmin)
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_rounded),
                      title: const Text('Add counsellor / admin'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStaffScreen()));
                      },
                    ),
                ]),
                child: InitialsAvatar(me.fullName, size: 44),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_stats == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else ...[
                Row(children: [
                  _stat('Urgent', _n('urgent'), Icons.priority_high_rounded, AppColors.danger, AppColors.dangerSoft,
                      () => widget.onGoTab(1)),
                  const SizedBox(width: 12),
                  _stat('Waiting', _n('open'), Icons.mark_chat_unread_rounded, AppColors.amber, AppColors.amberSoft,
                      () => widget.onGoTab(1)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _stat('Active chats', _n('in_progress'), Icons.forum_rounded, AppColors.primary, AppColors.mint,
                      () => widget.onGoTab(1)),
                  const SizedBox(width: 12),
                  _stat('Session requests', _n('pending_appts'), Icons.event_note_rounded, AppColors.sky,
                      AppColors.skySoft, () => widget.onGoTab(2)),
                ]),
                const SizedBox(height: 12),
                SoftCard(
                  child: Row(children: [
                    _mini('Sessions today', _n('today_appts')),
                    _mini('Closed this week', _n('closed_7d')),
                    _mini('Students', _n('students')),
                  ]),
                ),
                if (_urgent.isNotEmpty) ...[
                  const SectionTitle('Urgent'),
                  for (final c in _urgent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InboxTile(c, onChanged: _load),
                    ),
                ],
                const SectionTitle('Career guidance'),
                SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      _mini('Careers in library', _n('careers')),
                      _mini('Career requests (30 days)', _n('career_requests_30d')),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Most saved careers', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _topCareers(),
                    const SizedBox(height: 12),
                    const Text('Students by preferred stream', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _streamBars(),
                  ]),
                ),
                const SectionTitle('How students feel (last 7 days)'),
                SoftCard(child: _moodBars()),
                const SectionTitle('Topics (last 30 days)'),
                SoftCard(child: _topicBars()),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, int n, IconData icon, Color c, Color bg, VoidCallback onTap) => Expanded(
        child: SoftCard(
          color: bg,
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: c),
            const SizedBox(height: 10),
            Text('$n', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c)),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _mini(String label, int n) => Expanded(
        child: Column(children: [
          Text('$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ]),
      );

  Widget _bar(String label, int value, int max, Color color, {Widget? lead}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          if (lead != null) ...[lead, const SizedBox(width: 8)],
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 10,
                color: color,
                backgroundColor: AppColors.background,
              ),
            ),
          ),
          SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.right)),
        ]),
      );

  Widget _moodBars() {
    final m = Map<String, dynamic>.from((_stats?['moods_7d'] as Map?) ?? {});
    final counts = {for (final x in moods) x.value: (m['${x.value}'] as num?)?.toInt() ?? 0};
    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) {
      return const Text('No mood check-ins yet.', style: TextStyle(color: AppColors.muted));
    }
    const colors = [AppColors.danger, AppColors.amber, AppColors.muted, AppColors.sky, AppColors.primary];
    return Column(children: [
      for (final x in moods.reversed)
        _bar(x.label, counts[x.value]!, max, colors[x.value - 1], lead: Text(x.emoji, style: const TextStyle(fontSize: 18))),
    ]);
  }

  Widget _topCareers() {
    final list = ((_stats?['top_careers'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (list.isEmpty) return const Text('No careers saved yet.', style: TextStyle(color: AppColors.muted));
    final max = (list.first['n'] as num).toInt();
    return Column(children: [
      for (final e in list) _bar(e['title'] as String, (e['n'] as num).toInt(), max, AppColors.amber),
    ]);
  }

  Widget _streamBars() {
    final m = Map<String, dynamic>.from((_stats?['streams'] as Map?) ?? {});
    if (m.isEmpty) return const Text('No students yet.', style: TextStyle(color: AppColors.muted));
    final entries = m.entries.map((e) => MapEntry(e.key, (e.value as num).toInt())).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;
    return Column(children: [
      for (final e in entries)
        _bar(e.key == 'not set' ? 'Not set' : streamFor(e.key).label, e.value, max, streamFor(e.key).color),
    ]);
  }

  Widget _topicBars() {
    final m = Map<String, dynamic>.from((_stats?['topics'] as Map?) ?? {});
    if (m.isEmpty) return const Text('No conversations yet.', style: TextStyle(color: AppColors.muted));
    final entries = m.entries.map((e) => MapEntry(e.key, (e.value as num).toInt())).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;
    return Column(children: [
      for (final e in entries) _bar(topicFor(e.key).label, e.value, max, topicFor(e.key).color),
    ]);
  }
}
