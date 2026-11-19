import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api.dart';
import '../theme.dart';

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.ink,
    ));
}

void showError(BuildContext context, Object e) => showSnack(context, friendlyError(e), error: true);

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24 && DateTime.now().day == t.day) return DateFormat.jm().format(t);
  if (d.inDays < 7) return DateFormat.E().format(t);
  return DateFormat('d MMM').format(t);
}

String niceDate(DateTime t) => DateFormat('EEE, d MMM · h:mm a').format(t);

/// White rounded card with a soft shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Border? border;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'open':
        return const Pill('Waiting', color: AppColors.amber, bg: AppColors.amberSoft);
      case 'in_progress':
        return const Pill('Active', color: AppColors.primary, bg: AppColors.mint);
      case 'closed':
        return const Pill('Closed', color: AppColors.muted, bg: Color(0xFFEEF2EF));
      case 'requested':
        return const Pill('Requested', color: AppColors.amber, bg: AppColors.amberSoft);
      case 'confirmed':
        return const Pill('Confirmed', color: AppColors.primary, bg: AppColors.mint);
      case 'declined':
        return const Pill('Declined', color: AppColors.danger, bg: AppColors.dangerSoft);
      case 'cancelled':
        return const Pill('Cancelled', color: AppColors.muted, bg: Color(0xFFEEF2EF));
      case 'completed':
        return const Pill('Completed', color: AppColors.sky, bg: AppColors.skySoft);
      default:
        return Pill(status, color: AppColors.muted, bg: const Color(0xFFEEF2EF));
    }
  }
}

class TopicIcon extends StatelessWidget {
  final String topic;
  final double size;
  const TopicIcon(this.topic, {super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final t = topicFor(topic);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(size * 0.34)),
      child: Icon(t.icon, color: t.color, size: size * 0.5),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool anonymous;
  const InitialsAvatar(this.name, {super.key, this.size = 44, this.anonymous = false});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: anonymous ? AppColors.lilacSoft : AppColors.mint,
        shape: BoxShape.circle,
      ),
      child: anonymous
          ? Icon(Icons.visibility_off_rounded, color: AppColors.lilac, size: size * 0.45)
          : Text(initials,
              style: TextStyle(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
              child: Icon(icon, size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorRetry(this.error, this.onRetry, {super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        message: friendlyError(error),
        action: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      );
}

/// Shows a 6-digit PIN for a student so the counsellor can write it down.
Future<void> showPinDialog(BuildContext context, {required String name, required String admissionNo, required String pin}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Login details'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Admission No: $admissionNo'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(pin,
              style: const TextStyle(
                  fontSize: 30, letterSpacing: 8, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
        ),
        const SizedBox(height: 12),
        const Text('Give this PIN to the student privately. They can change it in the app.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    ),
  );
}
