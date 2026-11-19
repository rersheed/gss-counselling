import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/api.dart';
import '../../widgets/common.dart';
import 'new_case_screen.dart';
import 'student_home.dart';

class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({super.key});
  @override
  State<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  late Future<List<CaseItem>> _future = Api.myCases();

  Future<void> _reload() async {
    final f = Api.myCases();
    setState(() { _future = f; });
    await f.catchError((_) => <CaseItem>[]);
  }

  Future<void> _new() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewCaseScreen()));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My chats')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New chat'),
      ),
      body: FutureBuilder<List<CaseItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorRetry(snap.error!, _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.forum_outlined,
              title: 'No chats yet',
              message: 'When something is on your mind, start a chat. The counsellor will reply here.',
              action: FilledButton(onPressed: _new, child: const Text('Start a chat')),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => CaseTile(list[i], onChanged: _reload),
            ),
          );
        },
      ),
    );
  }
}
