-- Run ONCE after you create your own user in
-- Supabase → Authentication → Users → "Add user" (email + password, tick "Auto confirm").
-- Replace the email and name below, then run in the SQL Editor.

insert into public.profiles (id, role, full_name)
select id, 'admin', 'School Admin'           -- ← your name
from auth.users
where email = 'admin@example.com'            -- ← the email you just created
on conflict (id) do update set role = 'admin';
