-- =====================================================================
--  0002 — Career information module + student profile fields
--  Run after 0001_init.sql (Supabase → SQL Editor).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Career information (maintained by counsellors)
-- ---------------------------------------------------------------------
create table if not exists public.careers (
  id             bigint generated always as identity primary key,
  title          text not null unique check (char_length(title) between 2 and 80),
  stream         text not null check (stream in ('science', 'arts', 'commercial', 'technical')),
  summary        text not null check (char_length(summary) between 10 and 400),
  what_they_do   text check (char_length(what_they_do) <= 2000),
  ssce_subjects  text[] not null default '{}',   -- subjects commonly needed at credit level
  study_paths    text check (char_length(study_paths) <= 1000),
  skills         text[] not null default '{}',
  is_published   boolean not null default true,
  updated_by     uuid references public.profiles (id),
  updated_at     timestamptz not null default now(),
  created_at     timestamptz not null default now()
);

create index if not exists careers_stream_idx on public.careers (stream, title);

alter table public.careers enable row level security;

drop policy if exists "signed-in users read published careers" on public.careers;
create policy "signed-in users read published careers" on public.careers
  for select using (auth.uid() is not null and (is_published or public.is_staff()));

drop policy if exists "staff manage careers" on public.careers;
create policy "staff manage careers" on public.careers
  for all using (public.is_staff()) with check (public.is_staff());

create or replace function public.careers_touch()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists trg_careers_touch on public.careers;
create trigger trg_careers_touch before insert or update on public.careers
  for each row execute function public.careers_touch();

-- ---------------------------------------------------------------------
-- 2. Careers a student has saved ("My careers")
-- ---------------------------------------------------------------------
create table if not exists public.saved_careers (
  student_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  career_id   bigint not null references public.careers (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (student_id, career_id)
);

alter table public.saved_careers enable row level security;

drop policy if exists "student reads own saved careers" on public.saved_careers;
create policy "student reads own saved careers" on public.saved_careers
  for select using (student_id = auth.uid());

drop policy if exists "student saves careers" on public.saved_careers;
create policy "student saves careers" on public.saved_careers
  for insert with check (student_id = auth.uid() and public.my_role() = 'student');

drop policy if exists "student removes saved careers" on public.saved_careers;
create policy "student removes saved careers" on public.saved_careers
  for delete using (student_id = auth.uid());

-- ---------------------------------------------------------------------
-- 3. Student profile: preferred stream and career interests
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists preferred_stream text
  check (preferred_stream in ('science', 'arts', 'commercial', 'technical', 'undecided'));
alter table public.profiles add column if not exists career_interests text
  check (char_length(career_interests) <= 300);

create or replace function public.update_my_profile(p_stream text, p_interests text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() is distinct from 'student' then
    raise exception 'Only students can edit these details' using errcode = '42501';
  end if;
  update public.profiles
     set preferred_stream = nullif(p_stream, ''),
         career_interests = nullif(btrim(coalesce(p_interests, '')), '')
   where id = auth.uid();
end $$;

-- ---------------------------------------------------------------------
-- 4. Career guidance requests: a case can point at a career
-- ---------------------------------------------------------------------
alter table public.cases add column if not exists career_id bigint
  references public.careers (id) on delete set null;

drop function if exists public.open_case(text, text, text, boolean, boolean);
create or replace function public.open_case(
  p_topic text, p_subject text, p_body text,
  p_anonymous boolean default false, p_urgent boolean default false,
  p_career_id bigint default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_case uuid;
begin
  if public.my_role() is distinct from 'student' then
    raise exception 'Only students can open a case' using errcode = '42501';
  end if;
  insert into public.cases (student_id, topic, subject, is_anonymous, is_urgent, career_id)
  values (auth.uid(), p_topic, btrim(p_subject), p_anonymous, p_urgent, p_career_id)
  returning id into v_case;

  insert into public.messages (case_id, sender_role, body)
  values (v_case, 'student', btrim(p_body));
  return v_case;
end $$;

-- staff_inbox gains career_title, and (on named cases only) the student's
-- preferred stream and interests, so the counsellor has context.
drop function if exists public.staff_inbox(text, uuid);
create or replace function public.staff_inbox(
  p_status text default null, p_case uuid default null)
returns table (
  id uuid, display_name text, class_name text, gender text,
  is_anonymous boolean, topic text, subject text, is_urgent boolean,
  status text, assigned_to uuid, assigned_name text,
  last_message_at timestamptz, last_message_preview text,
  last_sender_role text, unread boolean, created_at timestamptz,
  career_title text, preferred_stream text, career_interests text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_staff() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  return query
  select c.id,
         case when c.is_anonymous then c.alias else p.full_name end,
         case when c.is_anonymous then null else p.class_name end,
         case when c.is_anonymous then null else p.gender end,
         c.is_anonymous, c.topic, c.subject, c.is_urgent, c.status,
         c.assigned_to, a.full_name,
         c.last_message_at, c.last_message_preview, c.last_sender_role,
         (c.last_sender_role = 'student'
            and (c.staff_last_read_at is null or c.staff_last_read_at < c.last_message_at)),
         c.created_at,
         cr.title,
         case when c.is_anonymous then null else p.preferred_stream end,
         case when c.is_anonymous then null else p.career_interests end
  from public.cases c
  join public.profiles p on p.id = c.student_id
  left join public.profiles a on a.id = c.assigned_to
  left join public.careers cr on cr.id = c.career_id
  where (p_status is null or c.status = p_status)
    and (p_case is null or c.id = p_case)
  order by (c.is_urgent and c.status <> 'closed') desc, c.last_message_at desc;
end $$;

-- staff_stats gains career figures (totals only, no names)
create or replace function public.staff_stats()
returns json language plpgsql stable security definer set search_path = public as $$
declare v json;
begin
  if not public.is_staff() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  select json_build_object(
    'open',          (select count(*) from cases where status = 'open'),
    'in_progress',   (select count(*) from cases where status = 'in_progress'),
    'urgent',        (select count(*) from cases where is_urgent and status <> 'closed'),
    'closed_7d',     (select count(*) from cases where status = 'closed'
                        and last_message_at > now() - interval '7 days'),
    'pending_appts', (select count(*) from appointments where status = 'requested'
                        and slot_start > now()),
    'today_appts',   (select count(*) from appointments where status = 'confirmed'
                        and (slot_start at time zone 'Africa/Lagos')::date
                            = (now() at time zone 'Africa/Lagos')::date),
    'students',      (select count(*) from profiles where role = 'student' and is_active),
    'careers',       (select count(*) from careers where is_published),
    'career_requests_30d', (select count(*) from cases where career_id is not null
                        and created_at > now() - interval '30 days'),
    'topics',        (select coalesce(json_object_agg(topic, n), '{}'::json) from
                        (select topic, count(*) n from cases
                         where created_at > now() - interval '30 days' group by topic) t),
    'moods_7d',      (select coalesce(json_object_agg(mood, n), '{}'::json) from
                        (select mood, count(*) n from mood_logs
                         where created_at > now() - interval '7 days' group by mood) m),
    'top_careers',   (select coalesce(json_agg(json_build_object('title', title, 'n', n)), '[]'::json) from
                        (select c.title, count(*) n from saved_careers s
                         join careers c on c.id = s.career_id
                         group by c.title order by count(*) desc, c.title limit 5) x),
    'streams',       (select coalesce(json_object_agg(coalesce(preferred_stream, 'not set'), n), '{}'::json) from
                        (select preferred_stream, count(*) n from profiles
                         where role = 'student' and is_active group by preferred_stream) s)
  ) into v;
  return v;
end $$;

revoke execute on function public.open_case(text, text, text, boolean, boolean, bigint) from public, anon;
revoke execute on function public.staff_inbox(text, uuid) from public, anon;
revoke execute on function public.staff_stats() from public, anon;
revoke execute on function public.update_my_profile(text, text) from public, anon;
grant execute on function public.open_case(text, text, text, boolean, boolean, bigint) to authenticated;
grant execute on function public.staff_inbox(text, uuid) to authenticated;
grant execute on function public.staff_stats() to authenticated;
grant execute on function public.update_my_profile(text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Starter career information. General guidance only: counsellors should
--    check and edit these entries against the current JAMB brochure and
--    institution requirements before relying on them.
-- ---------------------------------------------------------------------
insert into public.careers (title, stream, summary, what_they_do, ssce_subjects, study_paths, skills)
select * from (values
  ('Medicine and Surgery', 'science',
   'Doctors diagnose and treat illness and injury in hospitals and clinics.',
   'Examine patients, order tests, prescribe treatment, perform procedures and advise on healthy living.',
   array['English Language','Mathematics','Biology','Chemistry','Physics'],
   'University degree (MBBS), usually six years, followed by a one-year housemanship.',
   array['Patience','Problem solving','Communication','Hard work']),
  ('Nursing', 'science',
   'Nurses care for patients and support doctors in hospitals, clinics and communities.',
   'Monitor patients, give medicines, dress wounds, educate families and run health programmes.',
   array['English Language','Mathematics','Biology','Chemistry','Physics'],
   'B.N.Sc. at a university or a diploma at a school of nursing.',
   array['Compassion','Attention to detail','Teamwork']),
  ('Pharmacy', 'science',
   'Pharmacists prepare and dispense medicines and advise people on how to use them safely.',
   'Check prescriptions, prepare medicines, advise patients and work in hospitals, community pharmacies or industry.',
   array['English Language','Mathematics','Biology','Chemistry','Physics'],
   'University degree in Pharmacy (Pharm.D or B.Pharm).',
   array['Accuracy','Science knowledge','Communication']),
  ('Computer Science and Software Development', 'science',
   'Computer scientists design software, websites, apps and computer systems.',
   'Write and test programs, build apps and databases, protect systems and solve problems with computers.',
   array['English Language','Mathematics','Physics','Chemistry or Biology'],
   'University degree or polytechnic diploma in Computer Science; short courses and self-study also help.',
   array['Logical thinking','Mathematics','Creativity','Patience']),
  ('Civil Engineering', 'science',
   'Civil engineers plan and build roads, bridges, buildings, dams and water systems.',
   'Design structures, supervise construction sites and check that buildings are safe.',
   array['English Language','Mathematics','Physics','Chemistry','Further Mathematics or Technical Drawing'],
   'University degree (B.Eng) or polytechnic HND in Civil Engineering.',
   array['Mathematics','Planning','Teamwork']),
  ('Agriculture', 'science',
   'Agricultural professionals grow crops, raise animals and help farmers produce more food.',
   'Manage farms, advise farmers, test soils and seeds, and run agribusinesses.',
   array['English Language','Mathematics','Chemistry','Biology or Agricultural Science'],
   'University degree, college of agriculture diploma, or practical farm training.',
   array['Hard work','Business sense','Love of nature']),
  ('Law', 'arts',
   'Lawyers advise people and organisations on the law and represent them in court.',
   'Give legal advice, draft agreements, argue cases in court and protect people''s rights.',
   array['English Language','Literature in English','Mathematics','Government','Christian or Islamic Religious Studies or History'],
   'University law degree (LL.B), then Nigerian Law School before being called to the Bar.',
   array['Reading and writing','Public speaking','Reasoning','Integrity']),
  ('Mass Communication and Journalism', 'arts',
   'Journalists and media workers gather news and share information through radio, TV, print and online media.',
   'Interview people, write and edit stories, present programmes and manage social media.',
   array['English Language','Literature in English','Mathematics','Government or Economics'],
   'University degree or polytechnic diploma in Mass Communication.',
   array['Writing','Curiosity','Confidence','Hausa and English skills']),
  ('Teaching', 'arts',
   'Teachers help children and young people learn in nursery, primary and secondary schools.',
   'Prepare lessons, teach, mark work and guide students.',
   array['English Language','Mathematics','Subjects related to what you want to teach'],
   'NCE at a college of education, or a university degree in Education.',
   array['Patience','Communication','Love for children']),
  ('Islamic and Arabic Studies', 'arts',
   'Graduates teach, research and work in religious, educational and community organisations.',
   'Teach Arabic and Islamic Studies, translate, and work in schools, media and community bodies.',
   array['English Language','Islamic Religious Studies','Arabic','Mathematics'],
   'University degree or NCE in Islamic Studies or Arabic.',
   array['Reading','Teaching','Languages']),
  ('Accounting', 'commercial',
   'Accountants keep and check financial records for businesses, government and organisations.',
   'Prepare accounts and budgets, check spending, handle tax and advise on money decisions.',
   array['English Language','Mathematics','Economics','Financial Accounting','Commerce'],
   'University degree or polytechnic diploma in Accounting, then professional exams such as ICAN.',
   array['Mathematics','Honesty','Attention to detail']),
  ('Business Administration', 'commercial',
   'Business managers plan and run organisations and small businesses.',
   'Manage staff, plan budgets, market products and grow businesses.',
   array['English Language','Mathematics','Economics','Commerce'],
   'University degree or polytechnic diploma; many also start their own business.',
   array['Leadership','Planning','Communication']),
  ('Banking and Finance', 'commercial',
   'Banking and finance workers help people and businesses save, borrow and manage money.',
   'Serve customers, process loans, analyse investments and manage risk.',
   array['English Language','Mathematics','Economics','Commerce or Financial Accounting'],
   'University degree or polytechnic diploma in Banking and Finance.',
   array['Mathematics','Customer service','Honesty']),
  ('Electrical Installation', 'technical',
   'Electricians install and repair wiring and electrical equipment in homes and businesses.',
   'Wire buildings, fit sockets and solar systems, find faults and repair equipment safely.',
   array['English Language','Mathematics','Physics','Electrical Installation or Basic Electricity'],
   'Technical college certificate (NABTEB), apprenticeship, or polytechnic diploma.',
   array['Safety awareness','Practical skills','Problem solving']),
  ('Fashion Design and Tailoring', 'technical',
   'Fashion designers create and sew clothing and accessories.',
   'Design styles, take measurements, cut and sew, and run a fashion business.',
   array['English Language','Mathematics','Clothing and Textiles or Fine Art'],
   'Apprenticeship, vocational training, or a diploma or degree in Fashion Design.',
   array['Creativity','Patience','Business sense'])
) v(title, stream, summary, what_they_do, ssce_subjects, study_paths, skills)
where not exists (select 1 from public.careers);
