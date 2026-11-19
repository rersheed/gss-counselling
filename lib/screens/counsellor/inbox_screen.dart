import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String? _filter; // null = all
  List<InboxItem>? _items;
  Object? _error;
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    // Any new message (from any student) refreshes the inbox live.
    _channel = db
        .channel('staff-inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 600), _load);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) db.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await Api.inbox(status: _filter);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = <String?, String>{null: 'All', 'open': 'Waiting', 'in_progress': 'Active', 'closed': 'Closed'};
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final f in filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.value),
                    selected: _filter == f.key,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _filter == f.key ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: _filter == f.key ? AppColors.primary : AppColors.line),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (_) {
                      setState(() {
                        _filter = f.key;
                        _items = null;
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_error != null && _items == null) return ErrorRetry(_error!, _load);
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (_items!.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'All clear',
        message: 'No conversations here. New messages from students will appear automatically.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => InboxTile(_items![i], onChanged: _load),
      ),
    );
  }
}

/// A row in the counsellor's inbox.
class InboxTile extends StatelessWidget {
  final InboxItem c;
  final VoidCallback onChanged;
  const InboxTile(this.c, {super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final topic = topicFor(c.topic);
    final urgent = c.isUrgent && c.status != 'closed';
    return SoftCard(
      padding: const EdgeInsets.all(14),
      border: urgent ? Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.4) : null,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              caseId: c.id,
              title: c.displayName,
              subtitle: [c.className, topic.label, c.subject].whereType<String>().join(' · '),
              topic: c.topic,
              status: c.status,
              isAnonymous: c.isAnonymous,
              isUrgent: c.isUrgent,
            ),
          ),
        );
        onChanged();
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InitialsAvatar(c.displayName, anonymous: c.isAnonymous),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  c.className == null ? c.displayName : '${c.displayName} · ${c.className}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: c.unread ? FontWeight.w800 : FontWeight.w700),
                ),
              ),
              Text(timeAgo(c.lastMessageAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 2),
            Text(c.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text(
                  (c.lastSenderRole == 'staff' ? 'You: ' : '') + (c.lastMessagePreview ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.unread ? AppColors.ink : AppColors.muted, fontSize: 13),
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
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (urgent) const Pill('Urgent', icon: Icons.priority_high_rounded, color: AppColors.danger, bg: AppColors.dangerSoft),
              Pill(topic.label, color: topic.color, bg: topic.soft),
              StatusPill(c.status),
              if (c.assignedName != null)
                Pill(c.assignedName!, icon: Icons.person_rounded, color: AppColors.muted, bg: AppColors.background),
            ]),
          ]),
        ),
      ]),
    );
  }
}
