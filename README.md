# GSS Unguwan Sarki — Guidance & Counselling app

An Android app (Flutter + Supabase) where students of Government Secondary School Unguwan Sarki
talk privately to the school counsellor, and the counsellor replies, books sessions and keeps an eye on wellbeing.

## What's inside

**Students** (log in with admission number + 6-digit PIN)
- Home: mood check-in (😢 → 😄), "Talk to a counsellor", "I need help now", topic shortcuts, next session, recent chats
- Private chat with the counsellor, live (Supabase Realtime)
- **Anonymous** option: the counsellor sees "Student 4CB6" instead of the name and class
- **Urgent** flag: goes to the top of the counsellor's inbox with a red border
- "Get help now" screen: urgent message button + tap-to-call help lines (112 and others you add)
- Book a face-to-face session (school days, 8 am–1 pm slots), cancel, see the counsellor's note
- Tips: exam stress, study timetable, bullying, peer pressure, feeling low, career choice, time, growing up
- Change PIN

**Counsellor / Admin** (log in with email + password)
- Overview: urgent / waiting / active chats, session requests, moods this week (totals only), topics this month
- Inbox: urgent first, unread dots, filters, updates live when a student writes
- Reply, close/reopen, mark/unmark urgent
- Sessions: confirm (with a note like "come to Block B"), decline, mark completed
- Students: add one, **paste a whole class list** (gets a PIN for each — copy straight into Excel/WhatsApp), reset PIN, disable
- Admin only: add counsellors/admins, and **reveal an anonymous student's identity for safeguarding** (reason is required and logged)

## Privacy design (enforced in the database, not just the app)
- A student can only ever read their own chats, sessions and moods (row-level security).
- Counsellors never read the `cases` table directly; they go through `staff_inbox()`, which replaces the name and class with an alias on anonymous chats. Student messages carry no user ID at all.
- Mood check-ins are visible to staff only as totals.
- Accounts are created only through the `manage-users` Edge Function, which checks the caller is a counsellor/admin.

---

## Setup (about 20 minutes)

### 1. Supabase
1. Create a project at supabase.com (choose a region close to Nigeria, e.g. EU West / London).
2. **SQL Editor** → paste all of `supabase/migrations/0001_init.sql` → Run.
3. **Authentication → Sign In / Providers → Email**: turn **off** "Allow new users to sign up" and **off** "Confirm email".
   (Only the school creates accounts.)
4. **Authentication → Users → Add user**: your own email + password, tick *Auto Confirm*.
5. Open `supabase/bootstrap_first_admin.sql`, put in that email and your name, run it in the SQL Editor. You are now the admin.
6. **Table Editor → helplines**: add the counsellor's phone number, the principal's, and any Kaduna help lines you trust.

### 2. Edge Function (creates student/staff logins)
```bash
npm i -g supabase            # or: brew install supabase/tap/supabase
supabase login
supabase link --project-ref YOUR-PROJECT-REF
supabase secrets set STUDENT_EMAIL_DOMAIN=students.gssunguwansarki.app
supabase functions deploy manage-users
```
`STUDENT_EMAIL_DOMAIN` must be the same as `studentEmailDomain` in `lib/config.dart`.
(Students never see or use this email — it's just how an admission number is stored in Supabase Auth.)

### 3. Flutter app
```bash
cd gss_counselling
flutter create . --org ng.sch.gssus --project-name gss_counselling --platforms android
flutter pub get
flutter analyze
flutter test
```
`flutter create .` adds the Android folder around the code; it does not overwrite `lib/`, the test, or the
AndroidManifest (which already has the Internet permission and phone-dialer access).

Put your keys in `lib/config.dart` (Supabase → Project Settings → API: *Project URL* and *anon public* key),
or pass them when building:
```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
The APK is in `build/app/outputs/flutter-apk/app-release.apk` — share it on WhatsApp or install from a laptop.
(For the Play Store, set up a signing key first: https://docs.flutter.dev/deployment/android)

### 4. First day
1. Log in as admin → tap your avatar → **Add counsellor**.
2. Counsellor → **Students** tab → the list icon at the top → paste a class list:
   ```
   Aisha Bello, GSSUS/2024/015, SS2 A, F
   Musa Ibrahim, GSSUS/2024/016, SS2 A, M
   ```
3. Tap **Copy list with PINs**, paste into Excel, print, and give each student their PIN privately.

---

## Files
```
lib/
  main.dart                  app start + login routing
  config.dart                Supabase keys, school name, session hours
  theme.dart                 colours, font (Plus Jakarta Sans), input style
  models.dart                data classes, topics, moods
  services/api.dart          every Supabase call in one place
  widgets/common.dart        cards, pills, avatars, empty states
  screens/common/            login, chat, help-now, account/change PIN
  screens/student/           home, new chat, chats, sessions + booking, tips
  screens/counsellor/        overview, inbox, sessions, students (+ bulk add), add staff
supabase/
  migrations/0001_init.sql   tables, row-level security, functions, realtime
  functions/manage-users/    Edge Function for creating/resetting accounts
  bootstrap_first_admin.sql  make yourself admin
```

## Good next steps
- Push notifications (Firebase Cloud Messaging + a database webhook on `messages`) so students and the counsellor get alerts when the app is closed.
- Hausa translation of the screens (`flutter_localizations` + `.arb` files).
- Termly PDF/Excel report for the principal (counts by topic and class, no names).
