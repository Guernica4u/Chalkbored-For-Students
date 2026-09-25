-- ChalkBored — security fixes
-- Run this once in the Supabase SQL editor. Safe to run again.
--
-- 1. People could edit their own profile row directly, which let a banned
--    account unban itself (and clear a timeout, or rename itself freely).
--    Nothing on the site edits profiles directly, so that rule goes.
-- 2. The moderator password and private-room passwords could be guessed over
--    and over with no limit. Now: 5 wrong tries in 15 minutes and you have
--    to wait.
--
-- AFTER running this, also set a NEW moderator password (the old one was
-- written in a public file). Run this on its own, with your own password:
--   select public.set_mod_password('pick-something-long-and-new');

-- ---------------------------------------------------------------- 1. profiles

drop policy if exists profiles_self on public.profiles;

-- ---------------------------------------------------------------- 2. guess limits

create table if not exists public.secret_attempts (
  id         bigserial primary key,
  user_id    uuid not null references public.profiles on delete cascade,
  kind       text not null,             -- 'mod' or 'room'
  created_at timestamptz not null default now()
);
create index if not exists secret_attempts_idx on public.secret_attempts (user_id, kind, created_at);
alter table public.secret_attempts enable row level security;   -- no policies: functions only

-- raises an error if this person has guessed wrong too often lately
create or replace function public.check_guess_limit(p_kind text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  select count(*) into n from secret_attempts
   where user_id = auth.uid() and kind = p_kind and created_at > now() - interval '15 minutes';
  if n >= 5 then
    raise exception 'Too many wrong passwords. Wait 15 minutes and try again.';
  end if;
end; $$;

create or replace function public.record_wrong_guess(p_kind text)
returns void language sql security definer set search_path = public, extensions as $$
  insert into secret_attempts (user_id, kind) values (auth.uid(), p_kind);
  delete from secret_attempts where created_at < now() - interval '1 day';
$$;

-- only the functions below should use these
revoke all on function public.check_guess_limit(text) from public, anon, authenticated;
revoke all on function public.record_wrong_guess(text) from public, anon, authenticated;

-- Type the password in the chat to become a site moderator (now with a guess limit).
create or replace function public.claim_mod(p_password text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare ok boolean;
begin
  if auth.uid() is null or is_banned() then return false; end if;
  perform check_guess_limit('mod');

  select value = crypt(p_password, value) into ok
  from app_config where key = 'mod_password';

  if coalesce(ok, false) then
    update profiles set is_mod = true where id = auth.uid();
    return true;
  end if;
  perform record_wrong_guess('mod');
  return false;
end; $$;

-- Join a room. Public: walk in. Private: password (with a guess limit), unless you're a site mod.
create or replace function public.join_room(p_room uuid, p_password text default null)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare priv boolean; ok boolean;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if is_banned() then raise exception 'You are banned.'; end if;

  select is_private into priv from rooms where id = p_room;
  if priv is null then raise exception 'No such room.'; end if;

  if priv and not is_site_mod() then
    perform check_guess_limit('room');
    select password_hash = crypt(coalesce(p_password, ''), password_hash) into ok
    from room_secrets where room_id = p_room;
    if not coalesce(ok, false) then
      perform record_wrong_guess('room');
      return false;
    end if;
  end if;

  insert into room_members (room_id, user_id, role)
  values (p_room, auth.uid(), 'member') on conflict do nothing;
  return true;
end; $$;

-- ---------------------------------------------------------------- who is a mod right now?
-- Anyone who read the old password could have made themselves a mod. Check
-- this list, then remove anyone who shouldn't be there, e.g.:
--   update public.profiles set is_mod = false where username = 'someone';
select username, created_at from public.profiles where is_mod order by created_at;
