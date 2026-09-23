-- Chalk Chat — auto mod + reports
-- Run this once in the Supabase SQL editor, AFTER supabase-schema.sql.
-- Safe to run again; it skips anything already there.
--
-- Auto mod (checked by the database on every message, mods and room mods skip it):
--   slow down    more than 5 messages in 10 seconds
--   repeat       the same message twice in a row within a minute
--   spam         one character repeated 15+ times ("aaaaaaaaaaaaaaaa")
--   blocked word anything on the blocked words list (mods manage it in the chat)
-- Each block is a strike. 3 strikes in 10 minutes = 10 minute timeout, and the
-- timeout shows up in the reports queue so mods can see it.
--
-- Reports:
--   anyone can report a message once. 3 different people reporting the same
--   message removes it automatically. Room owners/mods see reports for their
--   room, site mods see everything.

-- ---------------------------------------------------------------- tables

alter table public.profiles add column if not exists muted_until timestamptz;

create table if not exists public.blocked_words (
  word text primary key check (char_length(word) between 2 and 40)
);

create table if not exists public.automod_strikes (
  id         bigserial primary key,
  user_id    uuid not null references public.profiles on delete cascade,
  reason     text not null,
  created_at timestamptz not null default now()
);

create index if not exists strikes_user_idx on public.automod_strikes (user_id, created_at);

create table if not exists public.reports (
  id            bigserial primary key,
  kind          text not null default 'user' check (kind in ('user', 'automod')),
  message_id    bigint references public.messages on delete set null,
  msg_ref       bigint,    -- the message id, kept after the message is deleted
  room_id       uuid references public.rooms on delete cascade,
  channel_id    uuid references public.channels on delete set null,
  reported_user uuid references public.profiles on delete cascade,
  reporter_id   uuid references public.profiles on delete set null,
  body          text,      -- copy of the message, so it survives deletion
  reason        text,
  status        text not null default 'open' check (status in ('open', 'dismissed', 'actioned')),
  auto_removed  boolean not null default false,
  resolved_by   uuid references public.profiles on delete set null,
  resolved_at   timestamptz,
  created_at    timestamptz not null default now(),
  unique (msg_ref, reporter_id)
);

create index if not exists reports_open_idx on public.reports (status, created_at);

-- ---------------------------------------------------------------- sending

-- All messages now go through this. It returns null when the message was
-- sent, or a short reason when auto mod stopped it.
create or replace function public.send_message(p_channel uuid, p_body text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  me       profiles;
  room     uuid;
  v_body   text := btrim(coalesce(p_body, ''));
  plain    text;
  why      text;
  recent   int;
  last_msg text;
  strikes  int;
begin
  if auth.uid() is null then return 'Sign in first.'; end if;
  select * into me from profiles where id = auth.uid();
  if me.banned then return 'Your account is banned.'; end if;

  room := channel_room(p_channel);
  if room is null then return 'That channel is gone.'; end if;
  if not exists (select 1 from room_members where room_id = room and user_id = me.id) then
    return 'Join the room first.';
  end if;

  if char_length(v_body) = 0 then return null; end if;
  if char_length(v_body) > 500 then return 'Messages max out at 500 characters.'; end if;

  if me.muted_until is not null and me.muted_until > now() then
    return 'You''re timed out for ' || greatest(1, ceil(extract(epoch from me.muted_until - now()) / 60))::int || ' more min.';
  end if;

  -- people who run the room skip the filters
  if not can_manage_room(room) then
    select count(*) into recent from messages
      where user_id = me.id and created_at > now() - interval '10 seconds';
    if recent >= 5 then why := 'Slow down — too many messages at once.'; end if;

    if why is null then
      select m.body into last_msg from messages m
        where m.user_id = me.id and m.channel_id = p_channel and m.created_at > now() - interval '60 seconds'
        order by m.id desc limit 1;
      if last_msg is not null and lower(last_msg) = lower(v_body) then
        why := 'You just sent that.';
      end if;
    end if;

    if why is null and v_body ~ '(.)\1{14,}' then
      why := 'That looks like spam.';
    end if;

    if why is null then
      -- catch the usual swaps: 0→o 1→i 3→e 4→a 5→s 7→t 8→b @→a $→s !→i
      plain := translate(lower(v_body), '0134578@$!', 'oieastbasi');
      if exists (select 1 from blocked_words w where plain ~ ('\m' || w.word || '\M')) then
        why := 'That message has a blocked word.';
      end if;
    end if;

    if why is not null then
      insert into automod_strikes (user_id, reason) values (me.id, why);
      select count(*) into strikes from automod_strikes
        where user_id = me.id and created_at > now() - interval '10 minutes';

      if strikes >= 3 then
        update profiles set muted_until = now() + interval '10 minutes' where id = me.id;
        delete from automod_strikes where user_id = me.id;
        insert into reports (kind, room_id, channel_id, reported_user, body, reason)
        values ('automod', room, p_channel, me.id, v_body, 'Timed out 10 min after 3 auto mod blocks. Last: ' || why);
        return why || ' That''s 3 — you''re timed out for 10 minutes.';
      end if;
      return why;
    end if;
  end if;

  insert into messages (channel_id, user_id, body) values (p_channel, me.id, v_body);
  return null;
end; $$;

-- no more posting around the checks: direct inserts are closed
drop policy if exists messages_write on public.messages;

-- ---------------------------------------------------------------- reporting

create or replace function public.report_message(p_message bigint, p_reason text default null)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare m messages; room uuid; n int;
begin
  if auth.uid() is null then return 'Sign in first.'; end if;
  if is_banned() then return 'Your account is banned.'; end if;

  select * into m from messages where id = p_message;
  if m.id is null then return 'That message is already gone.'; end if;
  room := channel_room(m.channel_id);
  if not can_read_room(room) then return 'You can''t see that message.'; end if;
  if m.user_id = auth.uid() then return 'You can''t report yourself.'; end if;

  insert into reports (message_id, msg_ref, room_id, channel_id, reported_user, reporter_id, body, reason)
  values (m.id, m.id, room, m.channel_id, m.user_id, auth.uid(), m.body, left(nullif(btrim(coalesce(p_reason, '')), ''), 200))
  on conflict (msg_ref, reporter_id) do nothing;
  if not found then return 'You already reported that.'; end if;

  select count(distinct reporter_id) into n from reports where msg_ref = m.id and status = 'open';
  if n >= 3 then
    update reports set auto_removed = true where msg_ref = m.id;
    delete from messages where id = m.id;
    return 'Reported. That was the third report, so it''s been removed.';
  end if;
  return 'Reported. A moderator will take a look.';
end; $$;

-- p_action: 'dismiss' | 'remove' (delete the message) | 'timeout' (1 hour, site mods) | 'ban' (site mods)
create or replace function public.resolve_report(p_report bigint, p_action text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare r reports;
begin
  select * into r from reports where id = p_report;
  if r.id is null then return 'No such report.'; end if;
  if not (is_site_mod() or (r.room_id is not null and can_manage_room(r.room_id))) then
    return 'You can''t act on this report.';
  end if;
  if p_action in ('timeout', 'ban') and not is_site_mod() then
    return 'Only site mods can time out or ban.';
  end if;
  if p_action not in ('dismiss', 'remove', 'timeout', 'ban') then return 'Unknown action.'; end if;

  if p_action <> 'dismiss' and r.message_id is not null then
    delete from messages where id = r.message_id;
  end if;
  if p_action = 'timeout' then
    update profiles set muted_until = now() + interval '1 hour' where id = r.reported_user;
  end if;
  if p_action = 'ban' then
    update profiles set banned = true where id = r.reported_user;
  end if;

  -- close every open report about the same message (or this one, for auto mod rows)
  update reports
     set status = case when p_action = 'dismiss' then 'dismissed' else 'actioned' end,
         resolved_by = auth.uid(), resolved_at = now()
   where status = 'open'
     and (id = r.id or (r.msg_ref is not null and msg_ref = r.msg_ref));
  return null;
end; $$;

-- ---------------------------------------------------------------- blocked words

create or replace function public.set_blocked_word(p_word text, p_add boolean)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare w text := lower(btrim(coalesce(p_word, '')));
begin
  if not is_site_mod() then return 'Moderators only.'; end if;
  if char_length(w) < 2 or char_length(w) > 40 then return 'Words are 2–40 characters.'; end if;
  if w !~ '^[a-z0-9 ]+$' then return 'Letters, numbers and spaces only.'; end if;
  if p_add then
    insert into blocked_words (word) values (w) on conflict do nothing;
  else
    delete from blocked_words where word = w;
  end if;
  return null;
end; $$;

-- ---------------------------------------------------------------- row rules

alter table public.blocked_words   enable row level security;
alter table public.automod_strikes enable row level security;
alter table public.reports         enable row level security;

-- only site mods can see the word list; strikes have no policies (functions only)
drop policy if exists blocked_words_read on public.blocked_words;
create policy blocked_words_read on public.blocked_words for select to authenticated
  using (is_site_mod());

-- reports: site mods see all, room owners/mods see their room's
drop policy if exists reports_read on public.reports;
create policy reports_read on public.reports for select to authenticated
  using (is_site_mod() or (room_id is not null and can_manage_room(room_id)));

-- Fix: the old "edit your own profile" rule let a banned user unban
-- themselves. Nothing on the site edits profiles directly, so it goes.
drop policy if exists profiles_self on public.profiles;

-- live updates for the mod queue
do $$ begin
  alter publication supabase_realtime add table public.reports;
exception when duplicate_object then null; end $$;
