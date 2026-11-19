import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../counsellor/career_edit_screen.dart';
import '../student/new_case_screen.dart';

/// Career information library. Students browse and save careers;
/// counsellors see the same list with add/edit controls.
class CareersScreen extends StatefulWidget {
  const CareersScreen({super.key});
  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen> {
  List<Career>? _careers;
  Set<int> _saved = {};
  Object? _error;
  String? _stream; // null = all
  bool _savedOnly = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = Me.of(context);
    try {
      final list = await Api.careers();
      final saved = me.isStaff ? <int>{} : await Api.mySavedCareerIds();
      if (!mounted) return;
      setState(() {
        _careers = list;
        _saved = saved;
        _error = null;
        // Start a student on their preferred stream the first time.
        if (!me.isStaff && _stream == null && streams.any((s) => s.key == me.preferredStream)) {
          _stream = me.preferredStream;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleSave(Career c) async {
    final was = _saved.contains(c.id);
    setState(() => was ? _saved.remove(c.id) : _saved.add(c.id));
    try {
      was ? await Api.unsaveCareer(c.id) : await Api.saveCareer(c.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => was ? _saved.add(c.id) : _saved.remove(c.id));
      showError(context, e);
    }
  }

  Future<void> _open(Career c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CareerDetailScreen(
          career: c,
          saved: _saved.contains(c.id),
          onToggleSave: () => _toggleSave(c),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = Me.of(context);
    final list = (_careers ?? [])
        .where((c) => _stream == null || c.stream == _stream)
        .where((c) => !_savedOnly || _saved.contains(c.id))
        .where((c) =>
            _q.isEmpty ||
            c.title.toLowerCase().contains(_q) ||
            c.summary.toLowerCase().contains(_q) ||
            c.ssceSubjects.any((s) => s.toLowerCase().contains(_q)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(me.isStaff ? 'Career information' : 'Explore careers')),
      floatingActionButton: me.isStaff
          ? FloatingActionButton.extended(
              key: const ValueKey('add-career'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerEditScreen()));
                _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add career'),
            )
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('career-search'),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: inputDeco('Search careers or subjects', icon: Icons.search_rounded),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            _chip('All', _stream == null && !_savedOnly, () => setState(() {
                  _stream = null;
                  _savedOnly = false;
                })),
            if (!me.isStaff)
              _chip('Saved (${_saved.length})', _savedOnly, () => setState(() {
                    _savedOnly = !_savedOnly;
                    _stream = null;
                  }), icon: Icons.favorite_rounded),
            for (final s in streams)
              _chip(s.label, _stream == s.key, () => setState(() {
                    _stream = s.key;
                    _savedOnly = false;
                  }), icon: s.icon),
          ]),
        ),
        Expanded(child: _body(list, me)),
      ]),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          avatar: icon == null ? null : Icon(icon, size: 16, color: sel ? Colors.white : AppColors.muted),
          selected: sel,
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: sel ? AppColors.primary : AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          labelStyle: TextStyle(color: sel ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
          onSelected: (_) => onTap(),
        ),
      );

  Widget _body(List<Career> list, Profile me) {
    if (_error != null && _careers == null) return ErrorRetry(_error!, _load);
    if (_careers == null) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.work_outline_rounded,
        title: _savedOnly ? 'No saved careers yet' : 'No careers found',
        message: _savedOnly
            ? 'Tap the heart on a career to save it here.'
            : 'Try another stream or search word.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final c = list[i];
          final st = streamFor(c.stream);
          return SoftCard(
            key: ValueKey('career-${c.title}'),
            padding: const EdgeInsets.all(14),
            onTap: () => _open(c),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: st.soft, borderRadius: BorderRadius.circular(15)),
                child: Icon(st.icon, color: st.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(c.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pill(st.label, color: st.color, bg: st.soft),
                    if (!c.isPublished) const Pill('Hidden', color: AppColors.danger, bg: AppColors.dangerSoft),
                  ]),
                ]),
              ),
              if (!me.isStaff)
                IconButton(
                  onPressed: () => _toggleSave(c),
                  icon: Icon(_saved.contains(c.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: AppColors.danger),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class CareerDetailScreen extends StatefulWidget {
  final Career career;
  final bool saved;
  final VoidCallback? onToggleSave;
  const CareerDetailScreen({super.key, required this.career, this.saved = false, this.onToggleSave});

  @override
  State<CareerDetailScreen> createState() => _CareerDetailScreenState();
}

class _CareerDetailScreenState extends State<CareerDetailScreen> {
  late bool _saved = widget.saved;

  @override
  Widget build(BuildContext context) {
    final me = Me.of(context);
    final c = widget.career;
    final st = streamFor(c.stream);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (me.isStaff)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                    context, MaterialPageRoute(builder: (_) => CareerEditScreen(career: c)));
                if (changed == true && context.mounted) Navigator.pop(context);
              },
            )
          else
            IconButton(
              key: const ValueKey('save-career'),
              tooltip: _saved ? 'Remove from my careers' : 'Save to my careers',
              icon: Icon(_saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: AppColors.danger),
              onPressed: () {
                widget.onToggleSave?.call();
                setState(() => _saved = !_saved);
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
        SoftCard(
          color: st.soft,
          child: Row(children: [
            Icon(st.icon, color: st.color, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${st.label} stream', style: TextStyle(color: st.color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(c.summary, style: const TextStyle(height: 1.35)),
              ]),
            ),
          ]),
        ),
        if ((c.whatTheyDo ?? '').isNotEmpty) ...[
          const SectionTitle('What they do'),
          Text(c.whatTheyDo!, style: const TextStyle(height: 1.45, fontSize: 15)),
        ],
        if (c.ssceSubjects.isNotEmpty) ...[
          const SectionTitle('SSCE subjects usually needed (credit level)'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in c.ssceSubjects)
              Chip(
                label: Text(s),
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Requirements differ between institutions and change over time. Always confirm in the current '
            'JAMB brochure and with the school counsellor.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
        if ((c.studyPaths ?? '').isNotEmpty) ...[
          const SectionTitle('How to get there'),
          Text(c.studyPaths!, style: const TextStyle(height: 1.45, fontSize: 15)),
        ],
        if (c.skills.isNotEmpty) ...[
          const SectionTitle('Helpful skills'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in c.skills) Pill(s, color: AppColors.primary, bg: AppColors.mint),
          ]),
        ],
        if (!me.isStaff) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('ask-about-career'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewCaseScreen(topic: 'career', careerId: c.id, subject: 'Guidance on ${c.title}'),
              ),
            ),
            icon: const Icon(Icons.forum_rounded),
            label: const Text('Ask the counsellor about this career'),
          ),
        ],
      ]),
    );
  }
}
