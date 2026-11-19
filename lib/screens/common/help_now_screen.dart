import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models.dart';
import '../../services/api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../student/new_case_screen.dart';

/// "I need help now" — urgent message to the counsellor + phone numbers.
class HelpNowScreen extends StatefulWidget {
  const HelpNowScreen({super.key});
  @override
  State<HelpNowScreen> createState() => _HelpNowScreenState();
}

class _HelpNowScreenState extends State<HelpNowScreen> {
  // Shown even if the network is down.
  static const _fallback = [Helpline('National Emergency', '112', 'Police, fire, ambulance — free from any phone')];
  late Future<List<Helpline>> _lines = Api.helplines();

  Future<void> _call(String phone) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    if (!ok && mounted) showSnack(context, 'Could not open the phone app. Dial $phone', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Get help now')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
        SoftCard(
          color: AppColors.dangerSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.favorite_rounded, color: AppColors.danger),
              const SizedBox(width: 8),
              Text('You are not alone',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.danger)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'If you are hurt, in danger, or thinking about hurting yourself, tell an adult you trust right now — '
              'a teacher, the counsellor, a parent or guardian. You can also call one of the numbers below.',
              style: TextStyle(height: 1.4),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewCaseScreen(urgent: true)),
          ),
          icon: const Icon(Icons.priority_high_rounded),
          label: const Text('Send an urgent message to the counsellor'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Urgent messages go to the top of the counsellor\'s list.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        const SectionTitle('Call for help'),
        FutureBuilder<List<Helpline>>(
          future: _lines,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final lines = (snap.data == null || snap.data!.isEmpty) ? _fallback : snap.data!;
            return Column(children: [
              for (final h in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    onTap: () => _call(h.phone),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.call_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(h.phone,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          if (h.description != null)
                            Text(h.description!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ]),
                  ),
                ),
              if (snap.hasError)
                TextButton(
                  onPressed: () => setState(() { _lines = Api.helplines(); }),
                  child: const Text('Reload numbers'),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
