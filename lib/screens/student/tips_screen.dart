import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

class Tip {
  final String title;
  final String summary;
  final IconData icon;
  final Color color;
  final Color bg;
  final List<String> points;
  const Tip(this.title, this.summary, this.icon, this.color, this.bg, this.points);
}

/// Short self-help guides. Edit or add your own here.
const tips = <Tip>[
  Tip('Beating exam stress', 'Calm your mind before and during exams', Icons.self_improvement_rounded,
      AppColors.primary, AppColors.mint, [
    'Start revising early. Small daily study beats one long night before the exam.',
    'Sleep well the night before. A tired brain forgets what it learnt.',
    'Eat breakfast on exam day and drink water.',
    'When you feel panic, breathe in slowly for 4 counts, hold for 4, breathe out for 6. Repeat 3 times.',
    'Read every question twice. Start with the ones you know to build confidence.',
    'One bad paper does not decide your future. Talk to the counsellor if worry will not go away.',
  ]),
  Tip('Making a study timetable', 'Plan your week so nothing piles up', Icons.calendar_month_rounded, AppColors.sky,
      AppColors.skySoft, [
    'List all your subjects and mark the ones you find hardest.',
    'Give hard subjects time when your mind is fresh — early morning or right after school.',
    'Study in blocks of 30–40 minutes with 5–10 minute breaks.',
    'Leave time for prayer, chores, rest and play. A good timetable is one you can actually follow.',
    'Review your timetable every Sunday and adjust it.',
  ]),
  Tip('If you are being bullied', 'It is not your fault and you can stop it', Icons.front_hand_rounded,
      AppColors.danger, AppColors.dangerSoft, [
    'Bullying is when someone hurts, threatens, embarrasses or takes from you again and again.',
    'Stay calm and walk away if you can. Stay close to friends or near teachers.',
    'Write down what happened, when and who saw it.',
    'Tell someone — the counsellor, your form teacher, or a parent. You can message the counsellor anonymously in this app.',
    'If you see someone being bullied, report it. Silence helps the bully.',
  ]),
  Tip('Saying no to peer pressure', 'Stay true to yourself', Icons.groups_rounded, AppColors.lilac, AppColors.lilacSoft, [
    'Real friends respect your "no".',
    'Have a ready answer: "No thanks, my parents will kill me" or "I have lesson".',
    'Spend time with friends who share your values.',
    'If a group pushes you to smoke, drink, skip school or hurt someone, walk away and talk to an adult.',
  ]),
  Tip('When you feel sad or low', 'Small steps that help', Icons.favorite_rounded, Color(0xFFD9467A),
      Color(0xFFFBE8EF), [
    'Feeling sad sometimes is normal. Feeling sad most days for two weeks or more is a sign to talk to someone.',
    'Tell one person you trust how you feel.',
    'Move your body — walk, play football, help at home.',
    'Keep a routine: sleep, eat, school, rest.',
    'If you ever think about hurting yourself, tap "I need help now" on the Home screen right away.',
  ]),
  Tip('Choosing a career path', 'Science, Arts or Commercial?', Icons.school_rounded, AppColors.amber,
      AppColors.amberSoft, [
    'Think about the subjects you enjoy and do well in, not only what your friends choose.',
    'List 3 jobs you find interesting and find out which subjects they need for JAMB and WAEC.',
    'Talk with people who do those jobs.',
    'Book a session with the counsellor for a career talk — we can help you plan your subject combination.',
  ]),
  Tip('Managing your time', 'Do more with less stress', Icons.timer_rounded, Color(0xFF15A3A3), Color(0xFFE2F5F5), [
    'Write tomorrow\'s 3 most important tasks tonight.',
    'Do the hardest task first.',
    'Put your phone away while studying.',
    'Say "not now" to things that can wait.',
  ]),
  Tip('Growing up: body and feelings', 'Changes are normal', Icons.spa_rounded, Color(0xFF8A6D3B), Color(0xFFF4EEE3), [
    'During your teenage years your body, voice and feelings change. Everyone goes through it at their own pace.',
    'Keep clean: bath daily, wear clean clothes, brush your teeth.',
    'Mood swings are common. Rest, eat well and talk about how you feel.',
    'Questions you feel shy to ask? Ask the counsellor — anonymously if you prefer.',
  ]),
];

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tips for you')),
        body: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: tips.length,
          itemBuilder: (_, i) {
            final t = tips[i];
            return SoftCard(
              color: t.bg,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TipDetail(t))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Icon(t.icon, color: t.color),
                ),
                const Spacer(),
                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 4),
                Text(t.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ]),
            );
          },
        ),
      );
}

class TipDetail extends StatelessWidget {
  final Tip tip;
  const TipDetail(this.tip, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tip.title)),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 30), children: [
          SoftCard(
            color: tip.bg,
            child: Row(children: [
              Icon(tip.icon, color: tip.color, size: 36),
              const SizedBox(width: 14),
              Expanded(child: Text(tip.summary, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < tip.points.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tip.color, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(tip.points[i], style: const TextStyle(height: 1.45, fontSize: 15))),
              ]),
            ),
        ]),
      );
}
