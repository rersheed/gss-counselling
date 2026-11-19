import 'package:flutter/material.dart';

import 'theme.dart';

DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime? _dtn(dynamic v) => v == null ? null : _dt(v);

enum UserRole { student, counsellor, admin }

class Profile {
  final String id;
  final UserRole role;
  final String fullName;
  final String? admissionNo;
  final String? className;
  final String? gender;
  final String? phone;
  final bool isActive;
  final String? preferredStream;
  final String? careerInterests;

  Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.admissionNo,
    this.className,
    this.gender,
    this.phone,
    this.isActive = true,
    this.preferredStream,
    this.careerInterests,
  });

  bool get isStaff => role != UserRole.student;
  bool get isAdmin => role == UserRole.admin;
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        role: UserRole.values.byName(m['role'] as String),
        fullName: m['full_name'] as String,
        admissionNo: m['admission_no'] as String?,
        className: m['class_name'] as String?,
        gender: m['gender'] as String?,
        phone: m['phone'] as String?,
        isActive: (m['is_active'] as bool?) ?? true,
        preferredStream: m['preferred_stream'] as String?,
        careerInterests: m['career_interests'] as String?,
      );
}

/// Topics a student can choose when opening a conversation.
class Topic {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
  const Topic(this.key, this.label, this.icon, this.color, this.soft);
}

const topics = <Topic>[
  Topic('studies', 'Studies', Icons.menu_book_rounded, AppColors.sky, AppColors.skySoft),
  Topic('family', 'Family', Icons.home_rounded, AppColors.primary, AppColors.mint),
  Topic('friends', 'Friends', Icons.people_alt_rounded, AppColors.lilac, AppColors.lilacSoft),
  Topic('bullying', 'Bullying', Icons.front_hand_rounded, AppColors.danger, AppColors.dangerSoft),
  Topic('feelings', 'Feelings', Icons.favorite_rounded, Color(0xFFD9467A), Color(0xFFFBE8EF)),
  Topic('health', 'Health', Icons.healing_rounded, Color(0xFF15A3A3), Color(0xFFE2F5F5)),
  Topic('career', 'Career', Icons.school_rounded, AppColors.amber, AppColors.amberSoft),
  Topic('faith', 'Faith & values', Icons.auto_awesome_rounded, Color(0xFF8A6D3B), Color(0xFFF4EEE3)),
  Topic('other', 'Something else', Icons.chat_bubble_rounded, AppColors.muted, Color(0xFFEEF2EF)),
];

Topic topicFor(String key) =>
    topics.firstWhere((t) => t.key == key, orElse: () => topics.last);

/// A conversation as the student sees it.
class CaseItem {
  final String id;
  final String topic;
  final String subject;
  final bool isAnonymous;
  final bool isUrgent;
  final String status;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final String? lastSenderRole;
  final DateTime? studentLastReadAt;
  final int? careerId;

  CaseItem.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        topic = m['topic'] as String,
        subject = m['subject'] as String,
        isAnonymous = m['is_anonymous'] as bool,
        isUrgent = m['is_urgent'] as bool,
        status = m['status'] as String,
        lastMessageAt = _dt(m['last_message_at']),
        lastMessagePreview = m['last_message_preview'] as String?,
        lastSenderRole = m['last_sender_role'] as String?,
        studentLastReadAt = _dtn(m['student_last_read_at']),
        careerId = (m['career_id'] as num?)?.toInt();

  bool get unread =>
      lastSenderRole == 'staff' &&
      (studentLastReadAt == null || studentLastReadAt!.isBefore(lastMessageAt));
}

/// A conversation as the counsellor sees it (from staff_inbox()).
class InboxItem {
  final String id;
  final String displayName;
  final String? className;
  final String? gender;
  final bool isAnonymous;
  final String topic;
  final String subject;
  final bool isUrgent;
  final String status;
  final String? assignedName;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final String? lastSenderRole;
  final bool unread;
  final String? careerTitle;
  final String? preferredStream;
  final String? careerInterests;

  InboxItem.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        displayName = m['display_name'] as String,
        className = m['class_name'] as String?,
        gender = m['gender'] as String?,
        isAnonymous = m['is_anonymous'] as bool,
        topic = m['topic'] as String,
        subject = m['subject'] as String,
        isUrgent = m['is_urgent'] as bool,
        status = m['status'] as String,
        assignedName = m['assigned_name'] as String?,
        lastMessageAt = _dt(m['last_message_at']),
        lastMessagePreview = m['last_message_preview'] as String?,
        lastSenderRole = m['last_sender_role'] as String?,
        unread = (m['unread'] as bool?) ?? false,
        careerTitle = m['career_title'] as String?,
        preferredStream = m['preferred_stream'] as String?,
        careerInterests = m['career_interests'] as String?;
}

class Message {
  final int id;
  final String caseId;
  final String senderRole; // 'student' | 'staff'
  final String? staffId;
  final String? staffName;
  final String body;
  final DateTime createdAt;

  Message.fromMap(Map<String, dynamic> m)
      : id = (m['id'] as num).toInt(),
        caseId = m['case_id'] as String,
        senderRole = m['sender_role'] as String,
        staffId = m['staff_id'] as String?,
        staffName = m['staff_name'] as String?,
        body = m['body'] as String,
        createdAt = _dt(m['created_at']);
}

class Appointment {
  final String id;
  final String studentId;
  final DateTime slotStart;
  final String? reason;
  final String status;
  final String? counsellorId;
  final String? staffNote;
  final String? studentName;
  final String? studentClass;
  final String? counsellorName;

  Appointment.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        studentId = m['student_id'] as String,
        slotStart = _dt(m['slot_start']),
        reason = m['reason'] as String?,
        status = m['status'] as String,
        counsellorId = m['counsellor_id'] as String?,
        staffNote = m['staff_note'] as String?,
        studentName = (m['student'] as Map?)?['full_name'] as String?,
        studentClass = (m['student'] as Map?)?['class_name'] as String?,
        counsellorName = (m['counsellor'] as Map?)?['full_name'] as String?;

  bool get isUpcoming => slotStart.isAfter(DateTime.now());
}

class Helpline {
  final String name;
  final String phone;
  final String? description;
  const Helpline(this.name, this.phone, [this.description]);

  Helpline.fromMap(Map<String, dynamic> m)
      : name = m['name'] as String,
        phone = m['phone'] as String,
        description = m['description'] as String?;
}

/// Mood scale used on the student home screen (1 = very sad … 5 = great).
class Mood {
  final int value;
  final String emoji;
  final String label;
  final String reply;
  const Mood(this.value, this.emoji, this.label, this.reply);
}

const moods = <Mood>[
  Mood(1, '😢', 'Very sad',
      "I'm sorry today is hard. You don't have to carry it alone — talk to the counsellor."),
  Mood(2, '😟', 'Worried',
      'Worries feel smaller when you share them. The counsellor is ready to listen.'),
  Mood(3, '😐', 'Okay', 'Thanks for checking in. Small steps count.'),
  Mood(4, '🙂', 'Good', 'Nice! Keep doing what helps you feel this way.'),
  Mood(5, '😄', 'Great', "Wonderful! Share that energy with a friend today."),
];

/// Subject streams used in Nigerian senior secondary schools.
class SubjectStream {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
  const SubjectStream(this.key, this.label, this.icon, this.color, this.soft);
}

const streams = <SubjectStream>[
  SubjectStream('science', 'Science', Icons.science_rounded, AppColors.sky, AppColors.skySoft),
  SubjectStream('arts', 'Arts', Icons.menu_book_rounded, AppColors.lilac, AppColors.lilacSoft),
  SubjectStream('commercial', 'Commercial', Icons.storefront_rounded, AppColors.amber, AppColors.amberSoft),
  SubjectStream('technical', 'Technical', Icons.build_rounded, Color(0xFF15A3A3), Color(0xFFE2F5F5)),
];

SubjectStream streamFor(String? key) => streams.firstWhere((s) => s.key == key,
    orElse: () => const SubjectStream('undecided', 'Not decided yet', Icons.help_outline_rounded, AppColors.muted,
        Color(0xFFEEF2EF)));

/// A career in the school's career information library.
class Career {
  final int id;
  final String title;
  final String stream;
  final String summary;
  final String? whatTheyDo;
  final List<String> ssceSubjects;
  final String? studyPaths;
  final List<String> skills;
  final bool isPublished;

  Career({
    required this.id,
    required this.title,
    required this.stream,
    required this.summary,
    this.whatTheyDo,
    this.ssceSubjects = const [],
    this.studyPaths,
    this.skills = const [],
    this.isPublished = true,
  });

  factory Career.fromMap(Map<String, dynamic> m) => Career(
        id: (m['id'] as num).toInt(),
        title: m['title'] as String,
        stream: m['stream'] as String,
        summary: m['summary'] as String,
        whatTheyDo: m['what_they_do'] as String?,
        ssceSubjects: List<String>.from((m['ssce_subjects'] as List?) ?? const []),
        studyPaths: m['study_paths'] as String?,
        skills: List<String>.from((m['skills'] as List?) ?? const []),
        isPublished: (m['is_published'] as bool?) ?? true,
      );

  Map<String, dynamic> toRow() => {
        'title': title,
        'stream': stream,
        'summary': summary,
        'what_they_do': whatTheyDo,
        'ssce_subjects': ssceSubjects,
        'study_paths': studyPaths,
        'skills': skills,
        'is_published': isPublished,
      };
}
