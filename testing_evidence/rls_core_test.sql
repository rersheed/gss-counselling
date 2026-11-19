\set ON_ERROR_STOP 0
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000a2'),('00000000-0000-0000-0000-0000000000c1'),('00000000-0000-0000-0000-0000000000ad');
insert into profiles(id,role,full_name,admission_no,class_name,gender) values
 ('00000000-0000-0000-0000-0000000000a1','student','Aisha Bello','GSS/001','SS2 A','female'),
 ('00000000-0000-0000-0000-0000000000a2','student','Musa Ibrahim','GSS/002','JSS3 B','male'),
 ('00000000-0000-0000-0000-0000000000c1','counsellor','Mrs Hauwa Sani',null,null,'female'),
 ('00000000-0000-0000-0000-0000000000ad','admin','Mr Principal',null,null,'male');
set role authenticated;
-- student 1 opens an anonymous urgent case + a normal one
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000a1';
select open_case('bullying','Some seniors are bothering me','They take my food every break',true,true) as anon_case \gset
select open_case('studies','Maths is hard','I fail every test',false,false) as named_case \gset
select count(*) as s1_cases from cases;
-- student 2 cannot see student 1 cases/messages, cannot write into them
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000a2';
select count(*) as s2_sees_cases from cases;
select count(*) as s2_sees_msgs from messages;
insert into messages(case_id,sender_role,body) values (:'anon_case','student','hijack');
select count(*) as s2_sees_profiles from profiles;
insert into messages(case_id,sender_role,staff_id,body) values (:'anon_case','staff','00000000-0000-0000-0000-0000000000c1','fake staff');
select staff_stats();
-- counsellor
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000c1';
select count(*) as c_direct_cases from cases;
select display_name, class_name, is_anonymous, is_urgent, unread from staff_inbox();
insert into messages(case_id,sender_role,staff_id,body) values (:'anon_case','staff','00000000-0000-0000-0000-0000000000c1','I am here for you. Come see me.');
select sender_role, staff_id is null as no_identity, staff_name, body from messages where case_id=:'anon_case' order by id;
select display_name, status, assigned_name, unread from staff_inbox(null, :'anon_case');
select staff_stats();
select * from reveal_case_identity(:'anon_case','just curious');
-- student 1 sees reply and unread state
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000a1';
select subject, status, last_sender_role, (student_last_read_at < last_message_at) unread from cases order by created_at;
select mark_case_read(:'anon_case');
insert into mood_logs(mood) values (2);
insert into appointments(slot_start, reason) values (now() + interval '1 day','Talk about bullying') returning id as appt \gset
insert into appointments(slot_start, reason, status) values (now() + interval '1 day','x','confirmed');
select set_case_status(:'named_case','in_progress');
select set_case_status(:'named_case','closed');
insert into messages(case_id,sender_role,body) values (:'named_case','student','after close');
-- admin reveal
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000ad';
select * from reveal_case_identity(:'anon_case','Student reported ongoing physical threats; safeguarding check');
select count(*) reveals from identity_reveals;
-- counsellor confirms appointment
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000c1';
update appointments set status='confirmed', counsellor_id=auth.uid() where id=:'appt';
select a.status, p.full_name from appointments a join profiles p on p.id=a.student_id;
select staff_stats();
-- anon role
reset request.jwt.claim.sub; set role anon;
select count(*) anon_helplines from helplines;
select staff_inbox();
