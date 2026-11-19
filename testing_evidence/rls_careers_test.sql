\set ON_ERROR_STOP 0
insert into auth.users values ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000a2'),('00000000-0000-0000-0000-0000000000c1');
insert into profiles(id,role,full_name,admission_no,class_name) values
 ('00000000-0000-0000-0000-0000000000a1','student','Aisha Bello','GSS/001','SS2 A'),
 ('00000000-0000-0000-0000-0000000000a2','student','Musa Ibrahim','GSS/002','SS1 B'),
 ('00000000-0000-0000-0000-0000000000c1','counsellor','Mrs Sani',null,null);
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000a1';
select count(*) careers_visible from careers;
insert into careers(title,stream,summary) values ('Hack','arts','student should not insert');
select update_my_profile('science','I like helping sick people');
insert into saved_careers(career_id) select id from careers where title in ('Medicine and Surgery','Nursing');
select open_case('career','Guidance on Medicine','Which subjects should I take in SS2?',false,false,(select id from careers where title='Medicine and Surgery')) is not null as opened;
select open_case('career','Anon career q','private',true,false,null) is not null as anon_opened;
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000a2';
select count(*) a2_sees_saved from saved_careers;
select update_my_profile('arts','law');
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000c1';
select display_name, career_title, preferred_stream, career_interests from staff_inbox();
update careers set summary = 'Doctors diagnose and treat illness and injury (edited).' where title='Medicine and Surgery';
select title, updated_by is not null as stamped from careers where title='Medicine and Surgery';
update careers set is_published=false where title='Fashion Design and Tailoring';
select update_my_profile('arts','x');
select staff_stats()->'top_careers' top, staff_stats()->'streams' streams, staff_stats()->'careers' n;
set request.jwt.claim.sub='00000000-0000-0000-0000-0000000000a1';
select count(*) student_sees_after_unpublish from careers;
