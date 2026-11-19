-- =====================================================================
--  GSS Unguwan Sarki — Guidance & Counselling app
--  Supabase schema, row-level security and helper functions
--  Run this whole file once in Supabase → SQL Editor.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. Profiles (one row per login: student, counsellor or admin)
-- ---------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('student', 'counsellor', 'admin');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  role          public.user_role not null default 'student',
  full_name     text not null,
  admission_no  text unique,               -- students only
  class_name    text,                      -- e.g. "SS2 B"
  gender        text check (gender in ('male', 'female')),
  phone         text,                      -- staff only
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- Role helpers. SECURITY DEFINER so they can read profiles without
-- tripping over profiles' own RLS (avoids infinite recursion).
create or replace function public.my_role()
returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and is_active
$$;

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('counsellor', 'admin'), false)
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'admin', false)
$$;

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select using (id = auth.uid());

drop policy if exists "staff read all profiles" on public.profiles;
create policy "staff read all profiles" on public.profiles
  for select using (public.is_staff());

-- Students may see counsellors' names (for appointments), never other students.
drop policy if exists "everyone reads staff profiles" on public.profiles;
create policy "everyone reads staff profiles" on public.profiles
  for select using (auth.uid() is not null and role in ('counsellor', 'admin'));

-- No insert/update/delete policies: accounts are created and edited only by
-- the manage-users Edge Function (service role).

-- ---------------------------------------------------------------------
-- 2. Cases (a student's conversation thread with the counselling unit)
-- ---------------------------------------------------------------------
create table if not exists public.cases (
  id                    uuid primary key default gen_random_uuid(),
  student_id            uuid not null default auth.uid()
                          references public.profiles (id) on delete cascade,
  topic                 text not null check (topic in
                          ('studies','family','friends','bullying','health',
                           'feelings','career','faith','other')),
  subject               text not null check (char_length(subject) between 3 and 120),
  is_anonymous          boolean not null default false,
  alias                 text not null default
                          ('Student ' || upper(substr(md5(gen_random_uuid()::text), 1, 4))),
  is_urgent             boolean not null default false,
  status                text not null default 'open'
                          check (status in ('open', 'in_progress', 'closed')),
  assigned_to           uuid references public.profiles (id),
  last_message_at       timestamptz not null default now(),
  last_message_preview  text,
  last_sender_role      text check (last_sender_role in ('student', 'staff')),
  student_last_read_at  timestamptz,
  staff_last_read_at    timestamptz,
  created_at            timestamptz not null default now()
);

create index if not exists cases_student_idx on public.cases (student_id, last_message_at desc);
create index if not exists cases_inbox_idx   on public.cases (status, is_urgent, last_message_at desc);

alter table public.cases enable row level security;

-- Students see only their own cases. Staff have NO direct access to this
-- table: they go through staff_inbox(), which hides the student's identity
-- on anonymous cases.
drop policy if exists "student reads own cases" on public.cases;
create policy "student reads own cases" on public.cases
  for select using (student_id = auth.uid());

-- Inserts/updates happen through the functions below.

-- ---------------------------------------------------------------------
-- 3. Messages
-- ---------------------------------------------------------------------
create table if not exists public.messages (
  id           bigint generated always as identity primary key,
  case_id      uuid not null references public.cases (id) on delete cascade,
  sender_role  text not null check (sender_role in ('student', 'staff')),
  staff_id     uuid references public.profiles (id),   -- null on student messages
  staff_name   text,                                    -- filled by trigger
  body         text not null check (char_length(btrim(body)) between 1 and 4000),
  created_at   timestamptz not null default now(),
  -- student messages never carry an identity; staff messages always do
  check ((sender_role = 'student' and staff_id is null)
      or (sender_role = 'staff'   and staff_id is not null))
);

create index if not exists messages_case_idx on public.messages (case_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "student reads own messages" on public.messages;
create policy "student reads own messages" on public.messages
  for select using (exists (
    select 1 from public.cases c where c.id = case_id and c.student_id = auth.uid()));

drop policy if exists "staff read messages" on public.messages;
create policy "staff read messages" on public.messages
  for select using (public.is_staff());

drop policy if exists "student writes to own open case" on public.messages;
create policy "student writes to own open case" on public.messages
  for insert with check (
    sender_role = 'student' and staff_id is null
    and exists (select 1 from public.cases c
                where c.id = case_id and c.student_id = auth.uid()
                  and c.status <> 'closed'));

drop policy if exists "staff write messages" on public.messages;
create policy "staff write messages" on public.messages
  for insert with check (
    public.is_staff() and sender_role = 'staff' and staff_id = auth.uid());

-- Fill staff_name before insert
create or replace function public.messages_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.sender_role = 'staff' then
    select full_name into new.staff_name from public.profiles where id = new.staff_id;
  else
    new.staff_name := null;
  end if;
  new.created_at := now();
  return new;
end $$;

drop trigger if exists trg_messages_before_insert on public.messages;
create trigger trg_messages_before_insert before insert on public.messages
  for each row execute function public.messages_before_insert();

-- Keep the case summary up to date after each message
create or replace function public.messages_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.cases c set
    last_message_at      = new.created_at,
    last_message_preview = left(new.body, 90),
    last_sender_role     = new.sender_role,
    status = case when new.sender_role = 'staff' and c.status = 'open'
                  then 'in_progress' else c.status end,
    assigned_to = case when new.sender_role = 'staff'
                       then coalesce(c.assigned_to, new.staff_id) else c.assigned_to end,
    student_last_read_at = case when new.sender_role = 'student'
                                then new.created_at else c.student_last_read_at end,
    staff_last_read_at   = case when new.sender_role = 'staff'
                                then new.created_at else c.staff_last_read_at end
  where c.id = new.case_id;
  return new;
end $$;

drop trigger if exists trg_messages_after_insert on public.messages;
create trigger trg_messages_after_insert after insert on public.messages
  for each row execute function public.messages_after_insert();

-- ---------------------------------------------------------------------
-- 4. Appointments (face-to-face sessions — never anonymous)
-- ---------------------------------------------------------------------
create table if not exists public.appointments (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null default auth.uid()
                   references public.profiles (id) on delete cascade,
  slot_start     timestamptz not null,
  reason         text check (char_length(reason) <= 500),
  status         text not null default 'requested'
                   check (status in ('requested','confirmed','declined','cancelled','completed')),
  counsellor_id  uuid references public.profiles (id),
  staff_note     text check (char_length(staff_note) <= 500),
  created_at     timestamptz not null default now()
);

create index if not exists appt_student_idx on public.appointments (student_id, slot_start desc);
create index if not exists appt_slot_idx    on public.appointments (slot_start);
-- one counsellor cannot have two confirmed sessions at the same time
create unique index if not exists appt_no_double_booking
  on public.appointments (counsellor_id, slot_start) where status = 'confirmed';

alter table public.appointments enable row level security;

drop policy if exists "student reads own appointments" on public.appointments;
create policy "student reads own appointments" on public.appointments
  for select using (student_id = auth.uid());

drop policy if exists "student requests appointment" on public.appointments;
create policy "student requests appointment" on public.appointments
  for insert with check (
    student_id = auth.uid() and public.my_role() = 'student'
    and status = 'requested' and counsellor_id is null and staff_note is null
    and slot_start > now());

drop policy if exists "staff read appointments" on public.appointments;
create policy "staff read appointments" on public.appointments
  for select using (public.is_staff());

drop policy if exists "staff update appointments" on public.appointments;
create policy "staff update appointments" on public.appointments
  for update using (public.is_staff()) with check (public.is_staff());

-- ---------------------------------------------------------------------
-- 5. Mood check-ins (one tap on the student home screen)
-- ---------------------------------------------------------------------
create table if not exists public.mood_logs (
  id          bigint generated always as identity primary key,
  student_id  uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  mood        smallint not null check (mood between 1 and 5),  -- 1 = very sad … 5 = great
  created_at  timestamptz not null default now()
);
create index if not exists mood_student_idx on public.mood_logs (student_id, created_at desc);

alter table public.mood_logs enable row level security;

drop policy if exists "student reads own moods" on public.mood_logs;
create policy "student reads own moods" on public.mood_logs
  for select using (student_id = auth.uid());

drop policy if exists "student logs mood" on public.mood_logs;
create policy "student logs mood" on public.mood_logs
  for insert with check (student_id = auth.uid() and public.my_role() = 'student');
-- staff only ever see totals, through staff_stats()

-- ---------------------------------------------------------------------
-- 6. Help lines shown on the "I need help now" screen (admin-editable)
-- ---------------------------------------------------------------------
create table if not exists public.helplines (
  id           bigint generated always as identity primary key,
  name         text not null,
  phone        text not null,
  description  text,
  sort_order   int not null default 100
);

alter table public.helplines enable row level security;

drop policy if exists "signed-in users read helplines" on public.helplines;
create policy "signed-in users read helplines" on public.helplines
  for select using (auth.uid() is not null);

drop policy if exists "admin manages helplines" on public.helplines;
create policy "admin manages helplines" on public.helplines
  for all using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 7. Safeguarding: audit log for revealing who wrote an anonymous case
-- ---------------------------------------------------------------------
create table if not exists public.identity_reveals (
  id          bigint generated always as identity primary key,
  case_id     uuid not null references public.cases (id) on delete cascade,
  admin_id    uuid not null references public.profiles (id),
  reason      text not null,
  created_at  timestamptz not null default now()
);

alter table public.identity_reveals enable row level security;

drop policy if exists "admin reads reveal log" on public.identity_reveals;
create policy "admin reads reveal log" on public.identity_reveals
  for select using (public.is_admin());

-- =====================================================================
-- RPC functions called from the app
-- =====================================================================

-- Student opens a new case with its first message (one atomic call)
create or replace function public.open_case(
  p_topic text, p_subject text, p_body text,
  p_anonymous boolean default false, p_urgent boolean default false)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_case uuid;
begin
  if public.my_role() is distinct from 'student' then
    raise exception 'Only students can open a case' using errcode = '42501';
  end if;
  insert into public.cases (student_id, topic, subject, is_anonymous, is_urgent)
  values (auth.uid(), p_topic, btrim(p_subject), p_anonymous, p_urgent)
  returning id into v_case;

  insert into public.messages (case_id, sender_role, body)
  values (v_case, 'student', btrim(p_body));
  return v_case;
end $$;

-- Staff inbox. Hides name/class on anonymous cases.
create or replace function public.staff_inbox(
  p_status text default null, p_case uuid default null)
returns table (
  id uuid, display_name text, class_name text, gender text,
  is_anonymous boolean, topic text, subject text, is_urgent boolean,
  status text, assigned_to uuid, assigned_name text,
  last_message_at timestamptz, last_message_preview text,
  last_sender_role text, unread boolean, created_at timestamptz)
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
         c.created_at
  from public.cases c
  join public.profiles p on p.id = c.student_id
  left join public.profiles a on a.id = c.assigned_to
  where (p_status is null or c.status = p_status)
    and (p_case is null or c.id = p_case)
  order by (c.is_urgent and c.status <> 'closed') desc, c.last_message_at desc;
end $$;

create or replace function public.mark_case_read(p_case uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public.is_staff() then
    update public.cases set staff_last_read_at = now() where id = p_case;
  else
    update public.cases set student_last_read_at = now()
    where id = p_case and student_id = auth.uid();
  end if;
end $$;

-- Staff: open / in_progress / closed.  Student: may close their own case.
create or replace function public.set_case_status(p_case uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_status not in ('open', 'in_progress', 'closed') then
    raise exception 'Bad status';
  end if;
  if public.is_staff() then
    update public.cases set status = p_status where id = p_case;
  elsif p_status = 'closed' then
    update public.cases set status = 'closed'
    where id = p_case and student_id = auth.uid();
  else
    raise exception 'Not allowed' using errcode = '42501';
  end if;
end $$;

create or replace function public.set_case_urgent(p_case uuid, p_urgent boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_staff() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  update public.cases set is_urgent = p_urgent where id = p_case;
end $$;

create or replace function public.cancel_my_appointment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.appointments set status = 'cancelled'
  where id = p_id and student_id = auth.uid()
    and status in ('requested', 'confirmed') and slot_start > now();
  if not found then
    raise exception 'This appointment cannot be cancelled';
  end if;
end $$;

-- Dashboard numbers for staff (moods are totals only — never per student)
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
    'topics',        (select coalesce(json_object_agg(topic, n), '{}'::json) from
                        (select topic, count(*) n from cases
                         where created_at > now() - interval '30 days' group by topic) t),
    'moods_7d',      (select coalesce(json_object_agg(mood, n), '{}'::json) from
                        (select mood, count(*) n from mood_logs
                         where created_at > now() - interval '7 days' group by mood) m)
  ) into v;
  return v;
end $$;

-- Safeguarding only: admin reveals who wrote an anonymous case. Logged.
create or replace function public.reveal_case_identity(p_case uuid, p_reason text)
returns table (full_name text, admission_no text, class_name text)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Only the admin can do this' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 10 then
    raise exception 'Please write the safeguarding reason (at least 10 characters)';
  end if;
  insert into public.identity_reveals (case_id, admin_id, reason)
  values (p_case, auth.uid(), btrim(p_reason));
  return query
  select p.full_name, p.admission_no, p.class_name
  from public.cases c join public.profiles p on p.id = c.student_id
  where c.id = p_case;
end $$;

-- Lock the functions down to signed-in users
revoke execute on function public.open_case(text, text, text, boolean, boolean) from public, anon;
revoke execute on function public.staff_inbox(text, uuid)            from public, anon;
revoke execute on function public.mark_case_read(uuid)               from public, anon;
revoke execute on function public.set_case_status(uuid, text)        from public, anon;
revoke execute on function public.set_case_urgent(uuid, boolean)     from public, anon;
revoke execute on function public.cancel_my_appointment(uuid)        from public, anon;
revoke execute on function public.staff_stats()                      from public, anon;
revoke execute on function public.reveal_case_identity(uuid, text)   from public, anon;
grant execute on function public.open_case(text, text, text, boolean, boolean) to authenticated;
grant execute on function public.staff_inbox(text, uuid)            to authenticated;
grant execute on function public.mark_case_read(uuid)               to authenticated;
grant execute on function public.set_case_status(uuid, text)        to authenticated;
grant execute on function public.set_case_urgent(uuid, boolean)     to authenticated;
grant execute on function public.cancel_my_appointment(uuid)        to authenticated;
grant execute on function public.staff_stats()                      to authenticated;
grant execute on function public.reveal_case_identity(uuid, text)   to authenticated;

-- ---------------------------------------------------------------------
-- Realtime: live chat + live appointment updates
-- ---------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.appointments;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.cases;
exception when others then null; end $$;

-- ---------------------------------------------------------------------
-- Starter help lines (edit these for Kaduna; add the counsellor's phone)
-- ---------------------------------------------------------------------
insert into public.helplines (name, phone, description, sort_order)
select * from (values
  ('National Emergency', '112', 'Police, fire, ambulance — free from any phone', 1),
  ('She Writes Woman (mental health)', '08008002000', 'Toll-free, answered at any hour', 2)
) v(name, phone, description, sort_order)
where not exists (select 1 from public.helplines);
