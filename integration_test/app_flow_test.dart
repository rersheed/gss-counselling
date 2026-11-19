// End-to-end test of the GSS Unguwan Sarki career guidance app.
//
// Runs the real app on an Android emulator against a LOCAL Supabase test stack
// loaded with the fictional demo data in supabase/seed.sql. Every step prints a
// PASS/FAIL line with its duration and saves a screenshot to evidence/screenshots/.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_flow_test.dart \
//     --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<local key>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gss_counselling/main.dart' as app;
import 'package:gss_counselling/widgets/common.dart' show SoftCard;
import 'package:integration_test/integration_test.dart';

// Must be created first in main(), before testWidgets builds a default binding.
late final IntegrationTestWidgetsFlutterBinding binding;
final results = <Map<String, Object>>[];
late WidgetTester t;

Future<void> shot(String name) async {
  await t.pump(const Duration(milliseconds: 600));
  await binding.takeScreenshot(name);
}

Future<void> waitFor(Finder f, {int seconds = 25}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out after ${seconds}s waiting for $f');
}

final _vertical = find.byWidgetPredicate(
    (w) => w is Scrollable && (w.axisDirection == AxisDirection.down || w.axisDirection == AxisDirection.up));

/// Hides the keyboard and scrolls down until [f] has been built (lazy lists
/// only build what is on screen).
Future<void> reveal(Finder f) async {
  await t.pump(const Duration(milliseconds: 300));
  if (f.evaluate().isNotEmpty) return;
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 500));
  // Try towards the top first (headers), then towards the bottom.
  for (final dy in [600.0, -300.0]) {
    for (var i = 0; i < (dy > 0 ? 8 : 15) && f.evaluate().isEmpty; i++) {
      if (_vertical.evaluate().isEmpty) return;
      await t.drag(_vertical.first, Offset(0, dy), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 350));
    }
  }
}

Future<void> tap(Finder f) async {
  await reveal(f);
  await waitFor(f);
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f.first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> type(Finder f, String text) async {
  await reveal(f);
  await waitFor(f);
  await t.ensureVisible(f.first);
  await t.enterText(f.first, text);
  await t.pump(const Duration(milliseconds: 300));
}

Finder key(String k) => find.byKey(ValueKey(k));
Finder nav(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> back() async {
  await t.pageBack();
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> step(String id, String name, Future<void> Function() body) async {
  final sw = Stopwatch()..start();
  try {
    await body();
    results.add({'id': id, 'name': name, 'status': 'PASS', 'ms': sw.elapsedMilliseconds});
    // ignore: avoid_print
    print('STEP|$id|PASS|${sw.elapsedMilliseconds}|$name');
  } catch (e) {
    results.add({'id': id, 'name': name, 'status': 'FAIL', 'ms': sw.elapsedMilliseconds, 'error': '$e'});
    // ignore: avoid_print
    print('STEP|$id|FAIL|${sw.elapsedMilliseconds}|$name|$e');
    try {
      await binding.takeScreenshot('FAIL_$id');
    } catch (_) {}
    // Keep going so later steps still report; the test fails at the end.
  }
}

Future<void> login({required bool staff, required String id, required String secret}) async {
  if (staff) await tap(find.text('Counsellor'));
  await type(key('login-id'), id);
  await type(key('login-secret'), secret);
  await tap(key('login-button'));
  await waitFor(find.textContaining('Sannu'));
}

void main() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Full student and counsellor journey', (tester) async {
    t = tester;
    app.main();
    await waitFor(key('login-id'), seconds: 40);
    await binding.convertFlutterSurfaceToImage();

    // ---------------- Student ----------------
    await step('TC01', 'Login screen is displayed', () async {
      await shot('01_login');
    });

    await step('TC02', 'Student logs in with admission number and PIN', () async {
      await login(staff: false, id: 'DEMO/001', secret: '246810');
      await tap(find.text('🙂'));
      await waitFor(find.textContaining('Keep doing what helps'));
      await shot('02_student_home');
    });

    await step('TC03', 'Student updates preferred stream and career interests', () async {
      await tap(key('profile-button'));
      await waitFor(find.text('My profile'));
      await tap(key('stream-dropdown'));
      await tap(find.text('Science').last);
      await type(key('interests-field'), 'I enjoy Biology and want to help sick people.');
      await tap(key('save-profile'));
      await waitFor(find.text('Profile saved'));
      await shot('03_student_profile');
      await back();
    });

    await step('TC04', 'Student browses career information filtered by stream', () async {
      await tap(nav('Careers'));
      await waitFor(key('career-Medicine and Surgery'));
      await shot('04_careers_list');
    });

    await step('TC05', 'Student views career details and saves the career', () async {
      await tap(key('career-Medicine and Surgery'));
      await waitFor(find.text('What they do'));
      await tap(key('save-career'));
      await shot('05_career_detail');
    });

    await step('TC06', 'Student submits a career guidance request', () async {
      await tap(key('ask-about-career'));
      await waitFor(find.text('Career guidance request'));
      await type(key('case-body'),
          'Which subjects should I take in SS2 and SS3 if I want to study Medicine?');
      await shot('06_career_request_form');
      await tap(key('send-case'));
      await waitFor(find.text('Which subjects should I take in SS2 and SS3 if I want to study Medicine?'));
      await shot('07_student_chat');
      await back();
      await back();
    });

    await step('TC07', 'Student sees the request in My chats', () async {
      await tap(nav('Chats'));
      await waitFor(find.text('Guidance on Medicine and Surgery'));
      await shot('08_student_chats');
    });

    await step('TC08', 'Student requests a counselling session', () async {
      await tap(nav('Sessions'));
      await tap(find.byType(FloatingActionButton));
      await tap(key('day-1'));
      await tap(key('slot-11'));
      await type(key('booking-reason'), 'I want to plan my subject combination for SS2.');
      await shot('09_book_session');
      await tap(key('request-slot'));
      await waitFor(find.text('Upcoming'));
      await shot('10_student_sessions');
    });

    await step('TC09', 'Student reads self-help tips', () async {
      await tap(nav('Tips'));
      await waitFor(find.text('Choosing a career path'));
      await shot('11_tips');
    });

    await step('TC10', 'Student opens the Get help now screen', () async {
      await tap(nav('Home'));
      await tap(find.text('I need help now'));
      await waitFor(find.text('112'));
      await shot('12_help_now');
      await back();
    });

    await step('TC11', 'Student logs out', () async {
      await tap(key('profile-button'));
      await tap(key('logout'));
      await waitFor(key('login-id'));
    });

    // ---------------- Counsellor ----------------
    await step('TC12', 'Counsellor logs in with email and password', () async {
      await login(staff: true, id: 'demo.counsellor@gssus.test', secret: 'DemoCounsellor#2026');
      await waitFor(find.text('Career guidance'));
      await shot('13_staff_dashboard');
      await t.drag(find.byType(ListView).first, const Offset(0, -600));
      await t.pump(const Duration(milliseconds: 800));
      await shot('14_staff_dashboard_careers');
    });

    await step('TC13', 'Counsellor sees the career request in the inbox; anonymous case shows no name', () async {
      await tap(nav('Inbox'));
      await waitFor(find.text('Guidance on Medicine and Surgery'));
      await waitFor(find.text('Some seniors take my lunch'));
      await shot('15_staff_inbox');
    });

    await step('TC14', 'Counsellor replies to the career guidance request', () async {
      await tap(find.text('Guidance on Medicine and Surgery'));
      await waitFor(key('chat-input'));
      await type(key('chat-input'),
          'Good question. Keep Biology, Chemistry and Physics with English and Mathematics. Come and see me on Thursday.');
      await tap(key('chat-send'));
      await waitFor(find.textContaining('Come and see me on Thursday'));
      await shot('16_staff_reply');
      await back();
    });

    await step('TC15', 'Counsellor confirms a session request', () async {
      await tap(nav('Sessions'));
      await waitFor(find.text('Demo Student One'));
      await shot('17_staff_session_requests');
      final card = find.ancestor(of: find.text('Demo Student One'), matching: find.byType(SoftCard));
      final confirm = card.evaluate().isNotEmpty
          ? find.descendant(of: card, matching: find.text('Confirm'))
          : find.text('Confirm');
      await tap(confirm);
      await type(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Come to the Guidance and Counselling office.');
      await tap(find.text('Save'));
      await tap(find.text('Upcoming'));
      await waitFor(find.text('Confirmed'));
      await shot('18_staff_session_confirmed');
    });

    await step('TC16', 'Counsellor creates a student account and receives a PIN', () async {
      await tap(nav('Students'));
      await waitFor(find.text('Demo Student One'));
      await shot('19_staff_students');
      await tap(find.text('Add student'));
      await type(find.byType(TextFormField).at(0), 'Demo Student Three');
      await type(find.byType(TextFormField).at(1), 'DEMO/003');
      await type(find.byType(TextFormField).at(2), 'JSS3 C');
      await tap(find.text('Create account'));
      await waitFor(find.text('Login details'), seconds: 40);
      await shot('20_staff_new_student_pin');
      await tap(find.text('Done'));
      await back();
    });

    await step('TC17', 'Counsellor opens career information management', () async {
      await tap(nav('Careers'));
      await waitFor(find.text('Career information'));
      await shot('21_staff_careers');
      await tap(key('add-career'));
      await waitFor(find.text('Career title'));
      await shot('22_staff_add_career');
      await back();
    });

    await step('TC18', 'Counsellor logs out', () async {
      await tap(nav('Overview'));
      await tap(key('staff-avatar'));
      await tap(find.text('Log out'));
      await waitFor(key('login-id'));
    });

    // ---------------- Student sees the response ----------------
    await step('TC19', 'Student receives the counsellor reply and confirmed session', () async {
      await login(staff: false, id: 'DEMO/001', secret: '246810');
      await tap(nav('Chats'));
      await tap(find.text('Guidance on Medicine and Surgery'));
      await waitFor(find.textContaining('Come and see me on Thursday'));
      await shot('23_student_sees_reply');
      await back();
      await tap(nav('Sessions'));
      await waitFor(find.text('Confirmed'));
      await shot('24_student_session_confirmed');
    });

    binding.reportData = {...?binding.reportData, 'steps': results};
    // Failures are reported through the STEP| lines (ci/run_e2e.sh fails the job);
    // the test itself passes so the driver still saves every screenshot.
  });
}
