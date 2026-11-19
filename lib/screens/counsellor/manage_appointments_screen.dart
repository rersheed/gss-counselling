import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});
  @override
  State<ManageAppointmentsScreen> createState() => _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  late Future<List<Appointment>> _future = Api.allAppointments();

  Future<void> _reload() async {
    final f = Api.allAppointments();
    setState(() => _future = f);
    await f.catchError((_) => <Appointment>[]);
  }

  Future<String?> _askNote(String title, {String hint = 'Note for the student (optional)'}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLines: 3, decoration: inputDeco(hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _update(Appointment a, String status) async {
    final me = Me.of(context);
    String? note;
    if (status == 'confirmed') {
      note = await _askNote('Confirm session', hint: 'e.g. Come to the counselling office, Block B');
    } else if (status == 'declined') {
      note = await _askNote('Decline request', hint: 'e.g. I am away that day — please pick another time');
    } else if (status == 'completed') {
      note = await _askNote('Mark as completed', hint: 'Short note the student will see (optional)');
    }
    if (note == null) return; // dialog dismissed
    try {
      await Api.updateAppointment(a.id, status,
          note: note, counsellorId: status == 'confirmed' ? me.id : null);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sessions'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Requests'), Tab(text: 'Upcoming'), Tab(text: 'Past')],
          ),
        ),
        body: FutureBuilder<List<Appointment>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorRetry(snap.error!, _reload);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final all = snap.data!;
            final requests = all.where((a) => a.status == 'requested' && a.isUpcoming).toList();
            final upcoming = all.where((a) => a.status == 'confirmed' && a.isUpcoming).toList();
            final past = all.where((a) => !requests.contains(a) && !upcoming.contains(a)).toList().reversed.toList();
            return TabBarView(children: [
              _list(requests, 'No new requests', (a) => [
                    Expanded(
                      child: OutlinedButton(onPressed: () => _update(a, 'declined'), child: const Text('Decline')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => _update(a, 'confirmed'),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ]),
              _list(upcoming, 'No confirmed sessions coming up', (a) => [
                    Expanded(
                      child: OutlinedButton(onPressed: () => _update(a, 'declined'), child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => _update(a, 'completed'),
                        child: const Text('Done'),
                      ),
                    ),
                  ]),
              _list(past, 'Nothing here yet', (a) => [
                    if (a.status == 'confirmed')
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () => _update(a, 'completed'),
                          child: const Text('Mark completed'),
                        ),
                      ),
                  ]),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(List<Appointment> items, String empty, List<Widget> Function(Appointment) actions) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.event_available_rounded, title: empty, message: 'Pull down to refresh.');
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final a = items[i];
          final acts = actions(a);
          return SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                InitialsAvatar(a.studentName ?? '?', size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.studentName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (a.studentClass != null)
                      Text(a.studentClass!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ]),
                ),
                StatusPill(a.status),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(niceDate(a.slotStart), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              if (a.reason != null) ...[
                const SizedBox(height: 6),
                Text(a.reason!, style: const TextStyle(color: AppColors.muted)),
              ],
              if (a.counsellorName != null) ...[
                const SizedBox(height: 4),
                Text('With ${a.counsellorName}', style: const TextStyle(fontSize: 12.5)),
              ],
              if (acts.isNotEmpty) ...[const SizedBox(height: 12), Row(children: acts)],
            ]),
          );
        },
      ),
    );
  }
}
