-- Row-level security and access-rule tests for the GSS Unguwan Sarki app.
-- Run against a freshly reset LOCAL Supabase database (never the live project):
--   psql "$DB_URL" -v ON_ERROR_STOP=0 -f testing_evidence/rls_test.sql
-- Each check prints one line: RESULT|<id>|PASS or FAIL|<description>
-- Test users below are fictional and exist only in the local test database.
\set ON_ERROR_STOP 0
\set QUIET 1
\pset tuples_only on
\pset format unaligned

-- ---------- fixtures (as the database owner) ----------
insert into auth.users (instance_id, id, aud, role, email) values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000a1','authenticated','authenticated','t-a1@test.local'),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000a2','authenticated','authenticated','t-a2@test.local'),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1','authenticated','authenticated','t-c1@test.local'),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000ad','authenticated','authenticated','t-ad@test.local');
insert into public.profiles (id, role, full_name, admission_no, class_name, gender) values
 ('00000000-0000-0000-0000-0000000000a1','student','Test Student A','TEST/001','SS2 A','female'),
 ('00000000-0000-0000-0000-0000000000a2','student','Test Student B','TEST/002','SS1 B','male'),
 ('00000000-0000-0000-0000-0000000000c1','counsellor','Test Counsellor',null,null,'female'),
 ('00000000-0000-0000-0000-0000000000ad','admin','Test Admin',null,null,'male');
\set ok f
select count(*) = 4 as ok from public.profiles where id::text like '00000000-0000-0000-0000-0000000000%' \gset
\if :ok
\echo RESULT|SETUP|PASS|Four fictional test users created
\else
\echo RESULT|SETUP|FAIL|Test users could not be created; results below are not valid
\endif

set role authenticated;

-- ================= Student A =================
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select open_case('bullying','Seniors bother me at break','They take my food every break', true, true) as anon_case \gset
select open_case('studies','Maths is hard','I fail every test', false, false) as named_case \gset
select open_case('career','Guidance on Medicine and Surgery','Which subjects should I take in SS2?', false, false,
                 (select id from careers where title = 'Medicine and Surgery')) as career_case \gset
\if :{?anon_case}
\if :{?named_case}
\if :{?career_case}
\echo RESULT|SETUP2|PASS|Test cases created for the checks that follow
\else
\echo RESULT|SETUP2|FAIL|Career case missing; later results are not valid
\endif
\else
\echo RESULT|SETUP2|FAIL|Named case missing; later results are not valid
\endif
\else
\echo RESULT|SETUP2|FAIL|Anonymous case missing; later results are not valid
\endif
\set ok f
select count(*) = 3 as ok from cases \gset
\if :ok
\echo RESULT|RLS01|PASS|Student opens cases (anonymous+urgent, named, career-linked) and sees exactly own 3
\else
\echo RESULT|RLS01|FAIL|Student opens cases and sees own cases
\endif

\set ok f
select count(*) > 0 as ok from careers \gset
\if :ok
\echo RESULT|RLS02|PASS|Signed-in student can read published careers
\else
\echo RESULT|RLS02|FAIL|Signed-in student can read published careers
\endif

insert into careers (title, stream, summary) values ('Hack career','arts','A student should not be able to add this');
\if :ERROR
\echo RESULT|RLS03|PASS|Student cannot add a career (blocked)
\else
\echo RESULT|RLS03|FAIL|Student was able to add a career
\endif

\set ok f
select update_my_profile('science','I like helping sick people');
\set ok f
select (preferred_stream = 'science') as ok from profiles where id = auth.uid() \gset
\if :ok
\echo RESULT|RLS04|PASS|Student updates own preferred stream and interests
\else
\echo RESULT|RLS04|FAIL|Student updates own preferred stream and interests
\endif

insert into saved_careers (career_id) select id from careers where title in ('Medicine and Surgery','Nursing');
\set ok f
select count(*) = 2 as ok from saved_careers \gset
\if :ok
\echo RESULT|RLS05|PASS|Student saves two careers and sees them
\else
\echo RESULT|RLS05|FAIL|Student saves two careers and sees them
\endif

insert into mood_logs (mood) values (2);
\if :ERROR
\echo RESULT|RLS06|FAIL|Student mood check-in was rejected
\else
\echo RESULT|RLS06|PASS|Student records a mood check-in
\endif

insert into appointments (slot_start, reason) values (now() + interval '1 day', 'Talk about subjects') returning id as appt \gset
\if :ERROR
\echo RESULT|RLS07|FAIL|Student session request was rejected
\else
\echo RESULT|RLS07|PASS|Student requests a session
\endif

insert into appointments (slot_start, reason, status) values (now() + interval '1 day', 'self-confirm', 'confirmed');
\if :ERROR
\echo RESULT|RLS08|PASS|Student cannot create an already-confirmed session (blocked)
\else
\echo RESULT|RLS08|FAIL|Student created a confirmed session directly
\endif

select set_case_status(:'named_case', 'in_progress');
\if :ERROR
\echo RESULT|RLS09|PASS|Student cannot set a case to In progress (staff only; students may only close)
\else
\echo RESULT|RLS09|FAIL|Student set a case to In progress
\endif

-- ================= Student B =================
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
\set ok f
select (select count(*) from cases) = 0 and (select count(*) from messages) = 0 and (select count(*) from saved_careers) = 0 as ok \gset
\if :ok
\echo RESULT|RLS10|PASS|Another student sees none of the cases, messages or saved careers of Student A
\else
\echo RESULT|RLS10|FAIL|Another student could see the data of Student A
\endif

insert into messages (case_id, sender_role, body) values (:'anon_case', 'student', 'hijack attempt');
\if :ERROR
\echo RESULT|RLS11|PASS|Another student cannot write into the case of Student A (blocked)
\else
\echo RESULT|RLS11|FAIL|Another student wrote into the case of Student A
\endif

insert into messages (case_id, sender_role, staff_id, body) values (:'anon_case', 'staff', '00000000-0000-0000-0000-0000000000c1', 'fake staff reply');
\if :ERROR
\echo RESULT|RLS12|PASS|Student cannot impersonate a counsellor (blocked)
\else
\echo RESULT|RLS12|FAIL|Student posted a message as staff
\endif

\set ok f
select count(*) = 1 as ok from profiles where role = 'student' \gset
\if :ok
\echo RESULT|RLS13|PASS|Student sees only own student profile (not other students)
\else
\echo RESULT|RLS13|FAIL|Student could see profiles of other students
\endif

select staff_stats();
\if :ERROR
\echo RESULT|RLS14|PASS|Student cannot read staff statistics (blocked)
\else
\echo RESULT|RLS14|FAIL|Student read staff statistics
\endif

select staff_inbox();
\if :ERROR
\echo RESULT|RLS15|PASS|Student cannot read the staff inbox (blocked)
\else
\echo RESULT|RLS15|FAIL|Student read the staff inbox
\endif

-- ================= Counsellor =================
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
\set ok f
select count(*) = 0 as ok from cases \gset
\if :ok
\echo RESULT|RLS16|PASS|Counsellor has no direct read access to the cases table
\else
\echo RESULT|RLS16|FAIL|Counsellor read the cases table directly
\endif

select (display_name like 'Student %' and display_name <> 'Test Student A' and class_name is null
        and preferred_stream is null and career_interests is null) as ok
  from staff_inbox(null, :'anon_case') \gset
\if :ok
\echo RESULT|RLS17|PASS|Anonymous case shows only an alias to the counsellor (no name, class or career profile)
\else
\echo RESULT|RLS17|FAIL|Anonymous case revealed identity to the counsellor
\endif

\set ok f
select (display_name = 'Test Student A' and career_title = 'Medicine and Surgery' and preferred_stream = 'science') as ok
  from staff_inbox(null, :'career_case') \gset
\if :ok
\echo RESULT|RLS18|PASS|Named career request shows student name, linked career and preferred stream
\else
\echo RESULT|RLS18|FAIL|Named career request details missing in inbox
\endif

\set ok f
select (id = :'anon_case'::uuid) as ok from staff_inbox() limit 1 \gset
\if :ok
\echo RESULT|RLS19|PASS|Urgent case is listed first in the inbox
\else
\echo RESULT|RLS19|FAIL|Urgent case is not first in the inbox
\endif

insert into messages (case_id, sender_role, staff_id, body) values (:'career_case', 'staff', auth.uid(), 'Take Biology, Chemistry and Physics. Come and see me on Thursday.');
\set ok f
select (staff_name = 'Test Counsellor') as ok from messages where case_id = :'career_case' and sender_role = 'staff' \gset
\if :ok
\echo RESULT|RLS20|PASS|Counsellor replies; reply carries the counsellor name
\else
\echo RESULT|RLS20|FAIL|Counsellor reply failed or name missing
\endif

select set_case_status(:'named_case', 'closed');
\if :ERROR
\echo RESULT|RLS21|FAIL|Counsellor could not close a case
\else
\echo RESULT|RLS21|PASS|Counsellor closes a case
\endif

update appointments set status = 'confirmed', counsellor_id = auth.uid() where id = :'appt';
\set ok f
select count(*) = 1 as ok from appointments where id = :'appt' and status = 'confirmed' \gset
\if :ok
\echo RESULT|RLS22|PASS|Counsellor confirms a session request
\else
\echo RESULT|RLS22|FAIL|Counsellor could not confirm a session request
\endif

update careers set summary = 'Doctors diagnose and treat illness and injury (edited in test).' where title = 'Medicine and Surgery';
\set ok f
select (updated_by = auth.uid()) as ok from careers where title = 'Medicine and Surgery' \gset
\if :ok
\echo RESULT|RLS23|PASS|Counsellor edits a career; editor is recorded
\else
\echo RESULT|RLS23|FAIL|Counsellor career edit failed or editor not recorded
\endif

update careers set is_published = false where title = 'Nursing';
\set ok f
select (s->>'career_requests_30d')::int >= 1 and (s->>'careers') is not null as ok from (select staff_stats() s) x \gset
\if :ok
\echo RESULT|RLS24|PASS|Counsellor reads aggregate statistics including career requests
\else
\echo RESULT|RLS24|FAIL|Counsellor statistics missing career figures
\endif

select * from reveal_case_identity(:'anon_case', 'curious');
\if :ERROR
\echo RESULT|RLS25|PASS|Counsellor cannot reveal an anonymous identity (admin only)
\else
\echo RESULT|RLS25|FAIL|Counsellor revealed an anonymous identity
\endif

-- ================= Student A again =================
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
\set ok f
select count(*) = 0 as ok from careers where title = 'Nursing' \gset
\if :ok
\echo RESULT|RLS26|PASS|Unpublished career is hidden from students
\else
\echo RESULT|RLS26|FAIL|Unpublished career still visible to students
\endif

\set ok f
select count(*) = 1 as ok from messages where case_id = :'career_case' and sender_role = 'staff' \gset
\if :ok
\echo RESULT|RLS27|PASS|Student sees the counsellor reply in own case
\else
\echo RESULT|RLS27|FAIL|Student cannot see the counsellor reply
\endif

insert into messages (case_id, sender_role, body) values (:'named_case', 'student', 'message after close');
\if :ERROR
\echo RESULT|RLS28|PASS|Student cannot write into a closed case (blocked)
\else
\echo RESULT|RLS28|FAIL|Student wrote into a closed case
\endif

-- ================= Administrator =================
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000ad';
select * from reveal_case_identity(:'anon_case', 'Safeguarding check after an urgent report (test)');
\if :ERROR
\echo RESULT|RLS29|FAIL|Administrator could not reveal identity
\else
\set ok f
select count(*) = 1 as ok from identity_reveals where case_id = :'anon_case' \gset
\if :ok
\echo RESULT|RLS29|PASS|Administrator reveals identity with a reason, and the reveal is logged
\else
\echo RESULT|RLS29|FAIL|Reveal was not logged
\endif
\endif

-- ================= Not signed in =================
reset request.jwt.claim.sub;
set role anon;
\set ok f
select (select count(*) from careers) = 0 and (select count(*) from helplines) = 0 and (select count(*) from profiles) = 0 as ok \gset
\if :ok
\echo RESULT|RLS30|PASS|A user who is not signed in sees no careers, help lines or profiles
\else
\echo RESULT|RLS30|FAIL|Unauthenticated access returned data
\endif
reset role;
