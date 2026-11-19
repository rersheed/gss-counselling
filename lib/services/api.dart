import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';

SupabaseClient get db => Supabase.instance.client;

/// Turns any Supabase/network error into a sentence a student can read.
String friendlyError(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Wrong admission number / email or PIN.';
    if (m.contains('banned')) return 'This account has been disabled. Please see the counsellor.';
    return e.message;
  }
  if (e is PostgrestException) {
    if (e.code == '42501') return 'You are not allowed to do that.';
    return e.message;
  }
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Server error (${e.status}).';
  }
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException')) {
    return 'No internet connection. Please check your data and try again.';
  }
  return s.replaceFirst('Exception: ', '');
}

class AuthService {
  /// "GSS/2024/015" -> "gss-2024-015@students.…"  (must match the Edge Function)
  static String studentEmail(String admissionNo) {
    final n = admissionNo
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '$n@${AppConfig.studentEmailDomain}';
  }

  static Future<void> signInStudent(String admissionNo, String pin) =>
      db.auth.signInWithPassword(email: studentEmail(admissionNo), password: pin.trim());

  static Future<void> signInStaff(String email, String password) =>
      db.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);

  static Future<void> signOut() => db.auth.signOut();

  static Future<void> changePassword(String newPassword) =>
      db.auth.updateUser(UserAttributes(password: newPassword));

  static Future<Profile?> loadMyProfile() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await db.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }
}

class Api {
  // ---------------- Student ----------------
  static Future<List<CaseItem>> myCases() async {
    final rows = await db.from('cases').select().order('last_message_at', ascending: false);
    return rows.map(CaseItem.fromMap).toList();
  }

  static Future<String> openCase({
    required String topic,
    required String subject,
    required String body,
    required bool anonymous,
    required bool urgent,
    int? careerId,
  }) async {
    final id = await db.rpc('open_case', params: {
      'p_topic': topic,
      'p_subject': subject,
      'p_body': body,
      'p_anonymous': anonymous,
      'p_urgent': urgent,
      'p_career_id': careerId,
    });
    return id as String;
  }

  static Future<void> logMood(int mood) => db.from('mood_logs').insert({'mood': mood});

  static Future<int?> todaysMood() async {
    final start = DateTime.now();
    final midnight = DateTime(start.year, start.month, start.day);
    final row = await db
        .from('mood_logs')
        .select('mood')
        .gte('created_at', midnight.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return (row?['mood'] as num?)?.toInt();
  }

  static Future<List<Appointment>> myAppointments() async {
    final rows = await db
        .from('appointments')
        .select('*, counsellor:profiles!counsellor_id(full_name)')
        .order('slot_start', ascending: false);
    return rows.map(Appointment.fromMap).toList();
  }

  static Future<void> requestAppointment(DateTime slot, String reason) =>
      db.from('appointments').insert({
        'slot_start': slot.toUtc().toIso8601String(),
        'reason': reason.trim().isEmpty ? null : reason.trim(),
      });

  static Future<void> cancelMyAppointment(String id) =>
      db.rpc('cancel_my_appointment', params: {'p_id': id});

  static Future<void> updateMyProfile({String? stream, String? interests}) =>
      db.rpc('update_my_profile', params: {'p_stream': stream ?? '', 'p_interests': interests ?? ''});

  // ---------------- Careers ----------------
  static Future<List<Career>> careers() async {
    final rows = await db.from('careers').select().order('title');
    return rows.map(Career.fromMap).toList();
  }

  static Future<Set<int>> mySavedCareerIds() async {
    final rows = await db.from('saved_careers').select('career_id');
    return rows.map((r) => (r['career_id'] as num).toInt()).toSet();
  }

  static Future<void> saveCareer(int id) => db.from('saved_careers').insert({'career_id': id});

  static Future<void> unsaveCareer(int id) => db.from('saved_careers').delete().eq('career_id', id);

  static Future<void> upsertCareer(Career c, {int? id}) async {
    if (id == null) {
      await db.from('careers').insert(c.toRow());
    } else {
      await db.from('careers').update(c.toRow()).eq('id', id);
    }
  }

  static Future<void> deleteCareer(int id) => db.from('careers').delete().eq('id', id);

  // ---------------- Shared ----------------
  static Stream<List<Message>> messages(String caseId) => db
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('case_id', caseId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(Message.fromMap).toList());

  static Future<void> sendMessage({
    required String caseId,
    required String body,
    required Profile me,
  }) =>
      db.from('messages').insert({
        'case_id': caseId,
        'sender_role': me.isStaff ? 'staff' : 'student',
        'staff_id': me.isStaff ? me.id : null,
        'body': body.trim(),
      });

  static Future<void> markRead(String caseId) =>
      db.rpc('mark_case_read', params: {'p_case': caseId});

  static Future<void> setCaseStatus(String caseId, String status) =>
      db.rpc('set_case_status', params: {'p_case': caseId, 'p_status': status});

  static Future<List<Helpline>> helplines() async {
    final rows = await db.from('helplines').select().order('sort_order');
    return rows.map(Helpline.fromMap).toList();
  }

  // ---------------- Staff ----------------
  static Future<List<InboxItem>> inbox({String? status}) async {
    final rows = await db.rpc('staff_inbox', params: {'p_status': status}) as List;
    return rows.map((r) => InboxItem.fromMap(r as Map<String, dynamic>)).toList();
  }

  static Future<InboxItem?> inboxItem(String caseId) async {
    final rows = await db.rpc('staff_inbox', params: {'p_case': caseId}) as List;
    return rows.isEmpty ? null : InboxItem.fromMap(rows.first as Map<String, dynamic>);
  }

  static Future<void> setCaseUrgent(String caseId, bool urgent) =>
      db.rpc('set_case_urgent', params: {'p_case': caseId, 'p_urgent': urgent});

  static Future<Map<String, dynamic>> staffStats() async {
    final v = await db.rpc('staff_stats');
    return Map<String, dynamic>.from(v as Map);
  }

  static Future<List<Appointment>> allAppointments() async {
    final rows = await db
        .from('appointments')
        .select('*, student:profiles!student_id(full_name, class_name), '
            'counsellor:profiles!counsellor_id(full_name)')
        .order('slot_start', ascending: true);
    return rows.map(Appointment.fromMap).toList();
  }

  static Future<void> updateAppointment(String id, String status, {String? note, String? counsellorId}) {
    final data = <String, dynamic>{'status': status};
    if (note != null) data['staff_note'] = note.trim().isEmpty ? null : note.trim();
    if (counsellorId != null) data['counsellor_id'] = counsellorId;
    return db.from('appointments').update(data).eq('id', id);
  }

  static Future<List<Profile>> students() async {
    final rows = await db.from('profiles').select().eq('role', 'student').order('full_name');
    return rows.map(Profile.fromMap).toList();
  }

  static Future<List<Profile>> staff() async {
    final rows = await db
        .from('profiles')
        .select()
        .inFilter('role', ['counsellor', 'admin']).order('full_name');
    return rows.map(Profile.fromMap).toList();
  }

  static Future<Map<String, dynamic>> revealIdentity(String caseId, String reason) async {
    final rows = await db.rpc('reveal_case_identity',
        params: {'p_case': caseId, 'p_reason': reason}) as List;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  /// Calls the manage-users Edge Function.
  static Future<Map<String, dynamic>> manageUsers(Map<String, dynamic> body) async {
    final res = await db.functions.invoke('manage-users', body: body);
    final data = res.data;
    if (res.status >= 400) {
      throw Exception(data is Map && data['error'] != null ? data['error'] : 'Server error');
    }
    return Map<String, dynamic>.from(data as Map);
  }
}
