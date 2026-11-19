-- =====================================================================
--  DEMONSTRATION DATA — LOCAL TESTING ONLY
--  Loaded automatically by `supabase start` / `supabase db reset` on a
--  developer machine or in GitHub Actions. NEVER run this on the live
--  school project. All people below are fictional.
--
--  Demo logins (local test environment only):
--    Counsellor : demo.counsellor@gssus.test   /  DemoCounsellor#2026
--    Student 1  : DEMO/001                      /  PIN 246810
--    Student 2  : DEMO/002                      /  PIN 135790
-- =====================================================================

create or replace function pg_temp.demo_user(p_id uuid, p_email text, p_password text, p_name text)
returns void language plpgsql as $$
begin
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, email_change, email_change_token_new, recovery_token)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email,
          extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', p_name),
          now(), now(), '', '', '', '');
  insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), p_id::text, p_id,
          jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
          'email', now(), now(), now());
end $$;

select pg_temp.demo_user('d0000000-0000-0000-0000-00000000c001', 'demo.counsellor@gssus.test',
                         'DemoCounsellor#2026', 'Mrs. Demo Counsellor');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000001', 'demo-001@students.gssunguwansarki.app',
                         '246810', 'Demo Student One');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000002', 'demo-002@students.gssunguwansarki.app',
                         '135790', 'Demo Student Two');

insert into public.profiles (id, role, full_name, admission_no, class_name, gender, preferred_stream) values
  ('d0000000-0000-0000-0000-00000000c001', 'counsellor', 'Mrs. Demo Counsellor', null, null, 'female', null),
  ('d0000000-0000-0000-0000-000000000001', 'student', 'Demo Student One', 'DEMO/001', 'SS2 A', 'female', null),
  ('d0000000-0000-0000-0000-000000000002', 'student', 'Demo Student Two', 'DEMO/002', 'SS1 B', 'male', 'commercial');

-- A little prior activity from Demo Student Two so the counsellor views are not empty.
do $$
declare v_case uuid;
begin
  perform set_config('request.jwt.claim.sub', 'd0000000-0000-0000-0000-000000000002', true);
  v_case := public.open_case('bullying', 'Some seniors take my lunch', 'Two seniors have been taking my food at break for a week.', true, true, null);
  v_case := public.open_case('studies', 'Help with Mathematics', 'I find Mathematics hard. How can I improve before WAEC?', false, false, null);
  insert into public.mood_logs (student_id, mood) values
    ('d0000000-0000-0000-0000-000000000002', 2),
    ('d0000000-0000-0000-0000-000000000002', 3);
  insert into public.saved_careers (student_id, career_id)
    select 'd0000000-0000-0000-0000-000000000002', id from public.careers where title in ('Accounting', 'Banking and Finance');
  insert into public.appointments (student_id, slot_start, reason)
    values ('d0000000-0000-0000-0000-000000000002', date_trunc('day', now()) + interval '2 days 10 hours',
            'I want to talk about choosing subjects for SS2.');
  perform set_config('request.jwt.claim.sub', '', true);
end $$;
