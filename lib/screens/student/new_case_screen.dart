import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../common/chat_screen.dart';

class NewCaseScreen extends StatefulWidget {
  final String? topic;
  final bool urgent;
  const NewCaseScreen({super.key, this.topic, this.urgent = false});

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  late String? _topic = widget.topic;
  late bool _urgent = widget.urgent;
  bool _anon = false;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_topic == null) {
      showSnack(context, 'Please choose a topic', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final id = await Api.openCase(
        topic: _topic!,
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        anonymous: _anon,
        urgent: _urgent,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            caseId: id,
            title: _subject.text.trim(),
            topic: _topic!,
            status: 'open',
            isAnonymous: _anon,
            isUrgent: _urgent,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_urgent ? 'Urgent message' : 'New conversation')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
          const Text('Topic', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in topics)
              ChoiceChip(
                selected: _topic == t.key,
                onSelected: (_) => setState(() => _topic = t.key),
                avatar: Icon(t.icon, size: 18, color: _topic == t.key ? Colors.white : t.color),
                label: Text(t.label),
                showCheckmark: false,
                selectedColor: t.color,
                backgroundColor: t.soft,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _topic == t.key ? Colors.white : AppColors.ink,
                ),
              ),
          ]),
          const SizedBox(height: 20),
          TextFormField(
            controller: _subject,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDeco('In a few words, what is it about?', icon: Icons.short_text_rounded),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Write at least 3 letters' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _body,
            minLines: 5,
            maxLines: 10,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDeco('Tell the counsellor what is happening',
                hint: 'Write as much or as little as you like. You can write in English or Hausa.'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write a message' : null,
          ),
          const SizedBox(height: 12),
          _SwitchCard(
            value: _anon,
            onChanged: (v) => setState(() => _anon = v),
            icon: Icons.visibility_off_rounded,
            color: AppColors.lilac,
            bg: AppColors.lilacSoft,
            title: 'Stay anonymous',
            text: 'The counsellor will not see your name or class. '
                'Only if we believe you are in serious danger can the school head see who you are, to keep you safe.',
          ),
          const SizedBox(height: 10),
          _SwitchCard(
            value: _urgent,
            onChanged: (v) => setState(() => _urgent = v),
            icon: Icons.priority_high_rounded,
            color: AppColors.danger,
            bg: AppColors.dangerSoft,
            title: 'This is urgent',
            text: 'Use this if you are not safe or need help today. It goes to the top of the counsellor\'s list.',
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            style: _urgent ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            icon: const Icon(Icons.send_rounded),
            label: Text(_busy ? 'Sending…' : 'Send to counsellor'),
          ),
        ]),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String text;

  const _SwitchCard({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => SoftCard(
        color: value ? bg : Colors.white,
        onTap: () => onChanged(!value),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.35)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged, activeTrackColor: color),
        ]),
      );
}
