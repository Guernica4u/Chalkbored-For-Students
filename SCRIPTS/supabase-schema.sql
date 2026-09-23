-- ChalkBored chat — database setup
-- Paste the whole file into the Supabase SQL editor and run it once.
--
-- Shape:
--   rooms      public or private. Global is a room. Private rooms are listed
--              for everyone but you need the password to get in.
--   channels   live inside a room.
--   messages   live inside a channel.
--
-- Who can do what:
--   site mod    typed the moderator password. Can do anything, anywhere.
--   room owner  made the room. Runs it, and appoints room mods.
--   room mod    appointed by the owner. Runs that room's channels and messages.
--   member      reads and posts.
--
-- Every rule below is enforced by the database, not the page, so editing the
-- JavaScript in a browser gets you nowhere.

-- Supabase keeps extensions in their own schema; make sure both exist there
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

-- ---------------------------------------------------------------- tables

create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  username   extensions.citext unique not null,
  is_mod     boolean not null default false,
  banned     boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.rooms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 40),
  is_private boolean not null default false,
  is_global  boolean not null default false,
  owner_id   uuid references public.profiles on delete set null,
  created_at timestamptz not null default now()
);

-- kept apart from rooms so nobody can read the hash: no select policy at all
create table if not exists public.room_secrets (
  room_id       uuid primary key references public.rooms on delete cascade,
  password_hash text not null
);

create table if not exists public.room_members (
  room_id   uuid references public.rooms on delete cascade,
  user_id   uuid references public.profiles on delete cascade,
  role      text not null default 'member' check (role in ('owner', 'mod', 'member')),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.channels (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.rooms on delete cascade,
  name       text not null check (char_length(name) between 1 and 30),
  created_by uuid references public.profiles on delete set null,
  created_at timestamptz not null default now(),
  unique (room_id, name)
);

create table if not exists public.messages (
  id         bigserial primary key,
  channel_id uuid not null references public.channels on delete cascade,
  user_id    uuid not null references public.profiles on delete cascade,
  body       text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists messages_channel_idx on public.messages (channel_id, id);
create index if not exists channels_room_idx on public.channels (room_id);

-- one row: the moderator password, hashed
create table if not exists public.app_config (
  key   text primary key,
  value text not null
);

-- ---------------------------------------------------------------- helpers

create or replace function public.is_site_mod(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select coalesce((select is_mod from profiles where id = uid), false);
$$;

create or replace function public.is_banned(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select coalesce((select banned from profiles where id = uid), false);
$$;

create or replace function public.room_role(p_room uuid, uid uuid default auth.uid())
returns text language sql stable security definer set search_path = public, extensions as $$
  select role from room_members where room_id = p_room and user_id = uid;
$$;

-- readable: public rooms for anyone signed in, private rooms for members, and
-- everything for site mods
create or replace function public.can_read_room(p_room uuid)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select is_site_mod()
      or exists (select 1 from rooms where id = p_room and is_private = false)
      or exists (select 1 from room_members where room_id = p_room and user_id = auth.uid());
$$;

-- can run the room: owner, room mod, or site mod
create or replace function public.can_manage_room(p_room uuid)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select is_site_mod() or coalesce(room_role(p_room) in ('owner', 'mod'), false);
$$;

create or replace function public.channel_room(p_channel uuid)
returns uuid language sql stable security definer set search_path = public, extensions as $$
  select room_id from channels where id = p_channel;
$$;

-- ---------------------------------------------------------------- new accounts

-- a profile appears the moment someone registers, and they land in Global
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare g uuid;
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'username', 'user'));

  select id into g from public.rooms where is_global limit 1;
  if g is not null then
    insert into public.room_members (room_id, user_id, role)
    values (g, new.id, 'member') on conflict do nothing;
  end if;

  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- actions

-- Set the moderator password. Run this yourself in the SQL editor:
--   select public.set_mod_password('your password here');
-- Only the hash is stored, and nobody can call this from the site.
create or replace function public.set_mod_password(p_password text)
returns void language sql security definer set search_path = public, extensions as $$
  insert into app_config (key, value)
  values ('mod_password', crypt(p_password, gen_salt('bf')))
  on conflict (key) do update set value = excluded.value;
$$;

revoke all on function public.set_mod_password(text) from public, anon, authenticated;

-- Type the password in the chat to become a site moderator.
create or replace function public.claim_mod(p_password text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare ok boolean;
begin
  if auth.uid() is null or is_banned() then return false; end if;

  select value = crypt(p_password, value) into ok
  from app_config where key = 'mod_password';

  if coalesce(ok, false) then
    update profiles set is_mod = true where id = auth.uid();
    return true;
  end if;
  return false;
end; $$;

-- Make a room. Public rooms are moderators only. Everyone else gets one
-- private room, and that's their lot.
create or replace function public.create_room(p_name text, p_private boolean, p_password text default null)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare new_id uuid; mine int;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if is_banned() then raise exception 'You are banned.'; end if;

  if not p_private and not is_site_mod() then
    raise exception 'Only moderators can make public rooms.';
  end if;

  if p_private and not is_site_mod() then
    select count(*) into mine from rooms where owner_id = auth.uid() and is_private;
    if mine >= 1 then raise exception 'You already have a private room.'; end if;
    if p_password is null or char_length(p_password) < 3 then
      raise exception 'Private rooms need a password of at least 3 characters.';
    end if;
  end if;

  insert into rooms (name, is_private, owner_id) values (p_name, p_private, auth.uid())
  returning id into new_id;

  insert into room_members (room_id, user_id, role) values (new_id, auth.uid(), 'owner');

  if p_private and p_password is not null then
    insert into room_secrets (room_id, password_hash) values (new_id, crypt(p_password, gen_salt('bf')));
  end if;

  insert into channels (room_id, name, created_by) values (new_id, 'general', auth.uid());
  return new_id;
end; $$;

-- Join a room. Public: walk in. Private: password, unless you're a site mod.
create or replace function public.join_room(p_room uuid, p_password text default null)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare priv boolean; ok boolean;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if is_banned() then raise exception 'You are banned.'; end if;

  select is_private into priv from rooms where id = p_room;
  if priv is null then raise exception 'No such room.'; end if;

  if priv and not is_site_mod() then
    select password_hash = crypt(coalesce(p_password, ''), password_hash) into ok
    from room_secrets where room_id = p_room;
    if not coalesce(ok, false) then return false; end if;
  end if;

  insert into room_members (room_id, user_id, role)
  values (p_room, auth.uid(), 'member') on conflict do nothing;
  return true;
end; $$;

-- The owner (or a site mod) hands out room-mod status.
create or replace function public.set_room_role(p_room uuid, p_username text, p_role text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare target uuid;
begin
  if not (is_site_mod() or room_role(p_room) = 'owner') then
    raise exception 'Only the room owner can do that.';
  end if;
  if p_role not in ('mod', 'member') then raise exception 'Unknown role.'; end if;

  select id into target from profiles where username = p_username;
  if target is null then raise exception 'No user by that name.'; end if;

  insert into room_members (room_id, user_id, role) values (p_room, target, p_role)
  on conflict (room_id, user_id) do update set role = excluded.role;
  return true;
end; $$;

-- Site mods only.
create or replace function public.set_banned(p_username text, p_banned boolean)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare target uuid;
begin
  if not is_site_mod() then raise exception 'Moderators only.'; end if;
  select id into target from profiles where username = p_username;
  if target is null then raise exception 'No user by that name.'; end if;
  update profiles set banned = p_banned where id = target;
  return true;
end; $$;

-- ---------------------------------------------------------------- row rules

alter table public.profiles     enable row level security;
alter table public.rooms        enable row level security;
alter table public.room_secrets enable row level security;
alter table public.room_members enable row level security;
alter table public.channels     enable row level security;
alter table public.messages     enable row level security;
alter table public.app_config   enable row level security;

-- profiles: everyone signed in can see names; only you edit you
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (true);

drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid() and is_mod = (select is_mod from profiles p where p.id = auth.uid()));

-- rooms: every room is listed (that's how private ones show up locked).
-- Making one goes through create_room, so no insert policy here.
drop policy if exists rooms_read on public.rooms;
create policy rooms_read on public.rooms for select to authenticated using (true);

drop policy if exists rooms_manage on public.rooms;
create policy rooms_manage on public.rooms for update to authenticated
  using (is_site_mod() or owner_id = auth.uid());

drop policy if exists rooms_delete on public.rooms;
create policy rooms_delete on public.rooms for delete to authenticated
  using ((is_site_mod() or owner_id = auth.uid()) and not is_global);

-- room_secrets: no policies, so nobody reads password hashes. The functions
-- above are security definer and bypass this on purpose.

-- room_members: you see the membership of rooms you can read
drop policy if exists members_read on public.room_members;
create policy members_read on public.room_members for select to authenticated
  using (can_read_room(room_id));

drop policy if exists members_leave on public.room_members;
create policy members_leave on public.room_members for delete to authenticated
  using (user_id = auth.uid() or can_manage_room(room_id));

-- channels: read what you can read; Global is site mods only; elsewhere the
-- owner and room mods
drop policy if exists channels_read on public.channels;
create policy channels_read on public.channels for select to authenticated
  using (can_read_room(room_id));

drop policy if exists channels_create on public.channels;
create policy channels_create on public.channels for insert to authenticated
  with check (
    not is_banned() and created_by = auth.uid() and
    case when (select is_global from rooms where id = room_id)
      then is_site_mod()
      else can_manage_room(room_id)
    end
  );

drop policy if exists channels_delete on public.channels;
create policy channels_delete on public.channels for delete to authenticated
  using (can_manage_room(room_id));

-- messages: read a room you're in, post as yourself, delete your own (or any,
-- if you run the room)
drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages for select to authenticated
  using (can_read_room(channel_room(channel_id)));

drop policy if exists messages_write on public.messages;
create policy messages_write on public.messages for insert to authenticated
  with check (
    user_id = auth.uid() and not is_banned()
    and exists (select 1 from room_members m where m.room_id = channel_room(channel_id) and m.user_id = auth.uid())
  );

drop policy if exists messages_delete on public.messages;
create policy messages_delete on public.messages for delete to authenticated
  using (user_id = auth.uid() or can_manage_room(channel_room(channel_id)));

-- app_config: locked. Only the functions touch it.

-- ---------------------------------------------------------------- live updates

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.channels;
alter publication supabase_realtime add table public.rooms;

-- ---------------------------------------------------------------- the Global room

insert into public.rooms (name, is_private, is_global)
select 'Global', false, true
where not exists (select 1 from public.rooms where is_global);

insert into public.channels (room_id, name)
select r.id, 'general' from public.rooms r
where r.is_global and not exists (select 1 from public.channels c where c.room_id = r.id);

-- ---------------------------------------------------------------- last step
-- Run this on its own, with your own password:
--   select public.set_mod_password('goop4u');


-- ---------------------------------------------------------------- backfill
-- Accounts registered BEFORE this file was run have no profile row, because
-- the trigger that makes one didn't exist yet. This gives them one and drops
-- them into Global. Safe to run whenever; it skips anyone already set up.

insert into public.profiles (id, username)
select u.id, coalesce(u.raw_user_meta_data ->> 'username', split_part(u.email, '@', 1))
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict do nothing;

insert into public.room_members (room_id, user_id, role)
select r.id, p.id, 'member'
from public.rooms r, public.profiles p
where r.is_global
on conflict do nothing;
