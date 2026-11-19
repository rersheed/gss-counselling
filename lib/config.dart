/// App-wide settings. Put your Supabase keys here, or pass them at build time:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kpxdqytqcqelbiutknub.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_ZpChElZf-5f5xsTSSB5g6Q_CVI4_YxD',
  );

  /// Students log in with admission number + PIN. Behind the scenes the
  /// admission number becomes an email on this domain. MUST match the
  /// STUDENT_EMAIL_DOMAIN secret of the manage-users Edge Function.
  static const studentEmailDomain = 'students.gssunguwansarki.app';

  static const schoolName = 'Government Secondary School Unguwan Sarki';
  static const schoolShort = 'GSS Unguwan Sarki';
  static const appName = 'Guidance & Counselling';

  /// Time slots students can request for a face-to-face session (school hours).
  static const sessionHours = [8, 9, 10, 11, 12, 13];

  /// How many school days ahead a student can book.
  static const bookingDaysAhead = 10;
}
