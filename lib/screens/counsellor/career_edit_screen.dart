import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Counsellors add or edit an entry in the career information library.
class CareerEditScreen extends StatefulWidget {
  final Career? career;
  const CareerEditScreen({super.key, this.career});
  @override
  State<CareerEditScreen> createState() => _CareerEditScreenState();
}

class _CareerEditScreenState extends State<CareerEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.career?.title);
  late final _summary = TextEditingController(text: widget.career?.summary);
  late final _what = TextEditingController(text: widget.career?.whatTheyDo);
  late final _subjects = TextEditingController(text: widget.career?.ssceSubjects.join(', '));
  late final _paths = TextEditingController(text: widget.career?.studyPaths);
  late final _skills = TextEditingController(text: widget.career?.skills.join(', '));
  late String _stream = widget.career?.stream ?? 'science';
  late bool _published = widget.career?.isPublished ?? true;
  bool _busy = false;

  List<String> _split(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final c = Career(
        id: widget.career?.id ?? 0,
        title: _title.text.trim(),
        stream: _stream,
        summary: _summary.text.trim(),
        whatTheyDo: _what.text.trim().isEmpty ? null : _what.text.trim(),
        ssceSubjects: _split(_subjects.text),
        studyPaths: _paths.text.trim().isEmpty ? null : _paths.text.trim(),
        skills: _split(_skills.text),
        isPublished: _published,
      );
      await Api.upsertCareer(c, id: widget.career?.id);
      if (!mounted) return;
      showSnack(context, 'Career saved');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this career?'),
        content: const Text('Students will no longer see it, and it is removed from their saved careers. '
            'To hide it for now instead, turn off "Show to students".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteCareer(widget.career!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.career == null ? 'Add career' : 'Edit career'),
          actions: [
            if (widget.career != null)
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(18), children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: inputDeco('Career title', icon: Icons.work_outline_rounded),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _stream,
              decoration: inputDeco('Stream', icon: Icons.category_outlined),
              items: [for (final s in streams) DropdownMenuItem(value: s.key, child: Text(s.label))],
              onChanged: (v) => setState(() => _stream = v ?? _stream),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summary,
              maxLines: 2,
              maxLength: 400,
              decoration: inputDeco('One-sentence summary'),
              validator: (v) => (v == null || v.trim().length < 10) ? 'At least 10 characters' : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _what,
              maxLines: 4,
              decoration: inputDeco('What they do (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjects,
              maxLines: 2,
              decoration: inputDeco('SSCE subjects, separated by commas',
                  helper: 'e.g. English Language, Mathematics, Biology, Chemistry, Physics'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paths,
              maxLines: 3,
              decoration: inputDeco('How to get there (optional)', hint: 'University, polytechnic, NCE, apprenticeship…'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skills,
              decoration: inputDeco('Helpful skills, separated by commas (optional)'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _published,
              onChanged: (v) => setState(() => _published = v),
              title: const Text('Show to students'),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primary,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save career')),
          ]),
        ),
      );
}
