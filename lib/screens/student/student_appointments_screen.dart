import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class StudentAppointmentsScreen extends StatefulWidget {
  const StudentAppointmentsScreen({super.key});
  @override
  State<StudentAppointmentsScreen> createState() => _StudentAppointmentsScreenState();
}

class _StudentAppointmentsScreenState extends State<StudentAppointmentsScreen> {
  late Future<List<Appointment>> _future = Api.myAppointments();

  Future<void> _reload() async {
    final f = Api.myAppointments();
    setState(() => _future = f);
    await f.catchError((_) => <Appointment>[]);
  }

  Future<void> _book() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const BookSessionScreen()));
    if (ok == true) _reload();
  }

  Future<void> _cancel(Appointment a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: Text(niceDate(a.slotStart)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel session')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await Api.cancelMyAppointment(a.id);
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        icon: const Icon(Icons.event_available_rounded),
        label: const Text('Book a session'),
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorRetry(snap.error!, _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_rounded,
              title: 'No sessions yet',
              message: 'Book a face-to-face talk with the counsellor at a time that suits you.',
              action: FilledButton(onPressed: _book, child: const Text('Book a session')),
            );
          }
          final upcoming = all
              .where((a) => a.isUpcoming && (a.status == 'requested' || a.status == 'confirmed'))
              .toList()
            ..sort((a, b) => a.slotStart.compareTo(b.slotStart));
          final past = all.where((a) => !upcoming.contains(a)).toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
              if (upcoming.isNotEmpty) const SectionTitle('Upcoming'),
              for (final a in upcoming) _tile(a, canCancel: true),
              if (past.isNotEmpty) const SectionTitle('History'),
              for (final a in past) _tile(a),
            ]),
          );
        },
      ),
    );
  }

  Widget _tile(Appointment a, {bool canCancel = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.event_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(niceDate(a.slotStart), style: const TextStyle(fontWeight: FontWeight.w700))),
              StatusPill(a.status),
            ]),
            if (a.reason != null) ...[
              const SizedBox(height: 8),
              Text(a.reason!, style: const TextStyle(color: AppColors.muted)),
            ],
            if (a.counsellorName != null) ...[
              const SizedBox(height: 6),
              Text('With ${a.counsellorName}', style: const TextStyle(fontSize: 13)),
            ],
            if (a.staffNote != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text('Note: ${a.staffNote}', style: const TextStyle(fontSize: 13)),
              ),
            ],
            if (canCancel)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => _cancel(a), child: const Text('Cancel')),
              ),
          ]),
        ),
      );
}

/// Pick a school day + time slot, inspired by the pill-style date pickers on Dribbble.
class BookSessionScreen extends StatefulWidget {
  const BookSessionScreen({super.key});
  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  late final List<DateTime> _days = _schoolDays();
  late DateTime _day = _days.first;
  int? _hour;
  final _reason = TextEditingController();
  bool _busy = false;

  static List<DateTime> _schoolDays() {
    final out = <DateTime>[];
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    // If today's last slot has passed, start tomorrow.
    if (DateTime.now().hour >= AppConfig.sessionHours.last) d = d.add(const Duration(days: 1));
    while (out.length < AppConfig.bookingDaysAhead) {
      if (d.weekday <= DateTime.friday) out.add(d);
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  DateTime _slot(int hour) => DateTime(_day.year, _day.month, _day.day, hour);

  Future<void> _submit() async {
    if (_hour == null) {
      showSnack(context, 'Pick a time', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.requestAppointment(_slot(_hour!), _reason.text);
      if (!mounted) return;
      showSnack(context, 'Request sent. You will see here when the counsellor confirms.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Book a session')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
        Text(DateFormat('MMMM y').format(_day), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final d = _days[i];
              final sel = d == _day;
              return GestureDetector(
                key: ValueKey('day-$i'),
                onTap: () => setState(() {
                  _day = d;
                  _hour = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.line),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(DateFormat.E().format(d),
                        style: TextStyle(color: sel ? Colors.white70 : AppColors.muted, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Text('${d.day}',
                        style: TextStyle(
                            color: sel ? Colors.white : AppColors.ink, fontSize: 20, fontWeight: FontWeight.w800)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        const Text('Time', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final h in AppConfig.sessionHours)
            Builder(builder: (_) {
              final past = _slot(h).isBefore(now.add(const Duration(minutes: 30)));
              final sel = _hour == h;
              return ChoiceChip(
                key: ValueKey('slot-$h'),
                label: Text(DateFormat.jm().format(_slot(h))),
                selected: sel,
                showCheckmark: false,
                onSelected: past ? null : (_) => setState(() => _hour = h),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? AppColors.primary : AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : (past ? AppColors.line : AppColors.ink),
                ),
              );
            }),
        ]),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('booking-reason'),
          controller: _reason,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: inputDeco('What would you like to talk about? (optional)'),
        ),
        const SizedBox(height: 6),
        SoftCard(
          color: AppColors.skySoft,
          padding: const EdgeInsets.all(14),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.sky),
            SizedBox(width: 10),
            Expanded(
              child: Text('Sessions are face to face in the counselling office, so the counsellor will know who you are.',
                  style: TextStyle(fontSize: 13)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
            key: const ValueKey('request-slot'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Sending…' : 'Request this time')),
      ]),
    );
  }
}
