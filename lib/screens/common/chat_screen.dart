import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// One conversation. Used by both students and counsellors.
class ChatScreen extends StatefulWidget {
  final String caseId;
  final String title;
  final String topic;
  final String status;
  final bool isAnonymous;
  final bool isUrgent;
  final String? subtitle;
  final String? studentContext;

  const ChatScreen({
    super.key,
    required this.caseId,
    required this.title,
    required this.topic,
    required this.status,
    required this.isAnonymous,
    required this.isUrgent,
    this.subtitle,
    this.studentContext,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<List<Message>> _stream = Api.messages(widget.caseId);
  late String _status = widget.status;
  late bool _urgent = widget.isUrgent;
  bool _sending = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    Api.markRead(widget.caseId).catchError((_) {});
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(Profile me) async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.sendMessage(caseId: widget.caseId, body: body, me: me);
      _text.clear();
      if (me.isStaff && _status == 'open') setState(() => _status = 'in_progress');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setStatus(String s) async {
    try {
      await Api.setCaseStatus(widget.caseId, s);
      setState(() => _status = s);
      if (mounted) showSnack(context, s == 'closed' ? 'Conversation closed' : 'Conversation reopened');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _toggleUrgent() async {
    try {
      await Api.setCaseUrgent(widget.caseId, !_urgent);
      setState(() => _urgent = !_urgent);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reveal() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reveal identity?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Only do this when a student may be in danger. Your name, the time and your reason are recorded.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(controller: reason, maxLines: 3, decoration: inputDeco('Safeguarding reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reveal'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final who = await Api.revealIdentity(widget.caseId, reason.text);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(who['full_name']?.toString() ?? ''),
          content: Text('Admission No: ${who['admission_no'] ?? '-'}\nClass: ${who['class_name'] ?? '-'}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Me.of(context);
    final closed = _status == 'closed';
    final topic = topicFor(widget.topic);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          me.isStaff
              ? InitialsAvatar(widget.title, size: 40, anonymous: widget.isAnonymous)
              : TopicIcon(widget.topic, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(widget.subtitle ?? topic.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'close':
                  _setStatus('closed');
                case 'reopen':
                  _setStatus('in_progress');
                case 'urgent':
                  _toggleUrgent();
                case 'reveal':
                  _reveal();
              }
            },
            itemBuilder: (_) => [
              if (!closed) const PopupMenuItem(value: 'close', child: Text('Close conversation')),
              if (closed && me.isStaff) const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
              if (me.isStaff)
                PopupMenuItem(value: 'urgent', child: Text(_urgent ? 'Remove urgent flag' : 'Mark as urgent')),
              if (me.isAdmin && widget.isAnonymous)
                const PopupMenuItem(value: 'reveal', child: Text('Reveal identity (safeguarding)')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (_urgent)
          _banner(Icons.priority_high_rounded, AppColors.danger, AppColors.dangerSoft,
              me.isStaff ? 'Marked urgent by the student — please respond quickly.' : 'Marked urgent. The counsellor will reply as soon as possible.'),
        if (me.isStaff && widget.studentContext != null)
          _banner(Icons.work_rounded, AppColors.amber, AppColors.amberSoft, widget.studentContext!),
        if (widget.isAnonymous)
          _banner(Icons.visibility_off_rounded, AppColors.lilac, AppColors.lilacSoft,
              me.isStaff
                  ? 'Anonymous — the student\'s name is hidden from you.'
                  : 'Anonymous — the counsellor cannot see your name.'),
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return ErrorRetry(snap.error!, () => setState(() {}));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snap.data!;
              if (msgs.length != _lastCount) {
                _lastCount = msgs.length;
                _scrollToEnd();
                Api.markRead(widget.caseId).catchError((_) {});
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = me.isStaff ? m.senderRole == 'staff' && m.staffId == me.id : m.senderRole == 'student';
                  final showDay = i == 0 || !_sameDay(msgs[i - 1].createdAt, m.createdAt);
                  return Column(children: [
                    if (showDay) _dayChip(m.createdAt),
                    _Bubble(message: m, mine: mine, viewerIsStaff: me.isStaff),
                  ]);
                },
              );
            },
          ),
        ),
        if (closed && !me.isStaff)
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Text('This conversation is closed. You can start a new one any time from Chats.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          )
        else
          _composer(me),
      ]),
    );
  }

  Widget _composer(Profile me) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          color: Colors.white,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                key: const ValueKey('chat-input'),
                controller: _text,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: me.isStaff ? 'Write a reply…' : 'Type your message…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const ValueKey('chat-send'),
              onPressed: _sending ? null : () => _send(me),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: _sending
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
            ),
          ]),
        ),
      );

  Widget _banner(IconData icon, Color c, Color bg, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: bg,
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dayChip(DateTime d) {
    final now = DateTime.now();
    final label = _sameDay(d, now)
        ? 'Today'
        : _sameDay(d, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : DateFormat('EEE, d MMM y').format(d);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Pill(label, color: AppColors.muted, bg: Colors.white),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool mine;
  final bool viewerIsStaff;
  const _Bubble({required this.message, required this.mine, required this.viewerIsStaff});

  @override
  Widget build(BuildContext context) {
    final r = const Radius.circular(20);
    final showName = message.senderRole == 'staff' && !mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: mine ? r : const Radius.circular(6),
            bottomRight: mine ? const Radius.circular(6) : r,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(message.staffName ?? 'Counsellor',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          Text(message.body,
              style: TextStyle(color: mine ? Colors.white : AppColors.ink, fontSize: 15, height: 1.35)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(DateFormat.jm().format(message.createdAt),
                style: TextStyle(fontSize: 10.5, color: mine ? Colors.white70 : AppColors.muted)),
          ),
        ]),
      ),
    );
  }
}
