// Unit tests for pure logic that does not need the network.
import 'package:flutter_test/flutter_test.dart';
import 'package:gss_counselling/config.dart';
import 'package:gss_counselling/models.dart';
import 'package:gss_counselling/services/api.dart';
import 'package:gss_counselling/widgets/common.dart';

void main() {
  group('UT01 login identity', () {
    test('admission number is normalised into the login email', () {
      expect(AuthService.studentEmail(' GSSUS/2024/015 '), 'gssus-2024-015@${AppConfig.studentEmailDomain}');
      expect(AuthService.studentEmail('demo/001'), AuthService.studentEmail('DEMO/001'));
    });
  });

  group('UT02 topics and streams', () {
    test('unknown keys fall back safely', () {
      expect(topicFor('nope').key, 'other');
      expect(topicFor('career').label, 'Career');
      expect(streamFor('science').label, 'Science');
      expect(streamFor(null).key, 'undecided');
    });
  });

  group('UT03 career model', () {
    test('fromMap and toRow round-trip', () {
      final c = Career.fromMap({
        'id': 7,
        'title': 'Nursing',
        'stream': 'science',
        'summary': 'Nurses care for patients.',
        'ssce_subjects': ['English Language', 'Biology'],
        'skills': ['Compassion'],
        'is_published': true,
      });
      expect(c.id, 7);
      expect(c.ssceSubjects, ['English Language', 'Biology']);
      final row = c.toRow();
      expect(row['title'], 'Nursing');
      expect(row.containsKey('id'), isFalse);
    });
  });

  group('UT04 unread logic', () {
    Map<String, dynamic> base(String sender, String? readAt) => {
          'id': 'x',
          'topic': 'career',
          'subject': 'Test',
          'is_anonymous': false,
          'is_urgent': false,
          'status': 'in_progress',
          'last_message_at': '2026-11-19T10:00:00Z',
          'last_sender_role': sender,
          'student_last_read_at': readAt,
        };
    test('a counsellor reply the student has not read is unread', () {
      expect(CaseItem.fromMap(base('staff', null)).unread, isTrue);
      expect(CaseItem.fromMap(base('staff', '2026-11-19T09:00:00Z')).unread, isTrue);
    });
    test('read replies and the student\'s own messages are not unread', () {
      expect(CaseItem.fromMap(base('staff', '2026-11-19T11:00:00Z')).unread, isFalse);
      expect(CaseItem.fromMap(base('student', null)).unread, isFalse);
    });
  });

  group('UT05 messages and appointments', () {
    test('message parsing keeps sender role and hides student identity', () {
      final m = Message.fromMap({
        'id': 3,
        'case_id': 'c',
        'sender_role': 'student',
        'staff_id': null,
        'staff_name': null,
        'body': 'Hello',
        'created_at': '2026-11-19T10:00:00Z',
      });
      expect(m.senderRole, 'student');
      expect(m.staffId, isNull);
    });
    test('appointment in the future is upcoming', () {
      final a = Appointment.fromMap({
        'id': 'a',
        'student_id': 's',
        'slot_start': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
        'status': 'requested',
        'student': {'full_name': 'Demo', 'class_name': 'SS1'},
      });
      expect(a.isUpcoming, isTrue);
      expect(a.studentName, 'Demo');
    });
  });

  group('UT06 time labels', () {
    test('very recent times show "now"', () {
      expect(timeAgo(DateTime.now()), 'now');
    });
  });
}
