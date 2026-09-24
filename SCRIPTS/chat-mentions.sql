-- Chalk Chat — @mentions
-- Run this once in the Supabase SQL editor, AFTER supabase-schema.sql and
-- chat-automod.sql. Safe to run again; it skips anything already there.
--
-- How it works:
--   write @username in a message and that person gets a mention
--   the database finds the @names itself when the message is saved, so
--   nobody can fake one from the browser
--   at most 5 people per message, never yourself, and only people who can
--   actually see the room (private rooms: members and site mods)
--   each person sees only their own mentions, and marks them read

-- ---------------------------------------------------------------- table

create table if not exists public.mentions (
  id         bigserial primary key,
  message_id bigint not null references public.messages on delete cascade,
  user_id    uuid not null references public.profiles on delete cascade,   -- who got mentioned
  by_user    uuid references public.profiles on delete set null,           -- who wrote the message
  room_id    uuid references public.rooms on delete cascade,
  channel_id uuid references public.channels on delete cascade,
  seen       boolean not null default false,
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);

create index if not exists mentions_user_idx on public.mentions (user_id, seen, created_at desc);

-- ---------------------------------------------------------------- finding @names

create or replace function public.make_mentions()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare
  v_room    uuid := channel_room(new.channel_id);
  v_private boolean;
  v_handle  text;
  v_target  uuid;
  v_count   int := 0;
begin
  select is_private into v_private from rooms where id = v_room;

  -- @name at the start or after a space/punctuation (so emails don't count)
  for v_handle in
    select distinct lower(rtrim(m[1], '.-'))
    from regexp_matches(new.body, '(?:^|[^A-Za-z0-9_@])@([A-Za-z0-9_.-]{2,20})', 'g') as m
  loop
    exit when v_count >= 5;

    select id into v_target from profiles where lower(username::text) = v_handle;
    continue when v_target is null or v_target = new.user_id;

    -- private rooms: only members (and site mods) get pinged
    continue when coalesce(v_private, true)
      and not exists (select 1 from room_members where room_id = v_room and user_id = v_target)
      and not exists (select 1 from profiles where id = v_target and is_mod);

    insert into mentions (message_id, user_id, by_user, room_id, channel_id)
    values (new.id, v_target, new.user_id, v_room, new.channel_id)
    on conflict do nothing;
    v_count := v_count + 1;
  end loop;

  return new;
end; $$;

drop trigger if exists messages_mentions on public.messages;
create trigger messages_mentions
  after insert on public.messages
  for each row execute function public.make_mentions();

-- ---------------------------------------------------------------- marking read

-- Pass a list of ids, or nothing to mark all of yours read.
create or replace function public.mark_mentions_seen(p_ids bigint[] default null)
returns void language sql security definer set search_path = public, extensions as $$
  update mentions set seen = true
   where user_id = auth.uid() and not seen
     and (p_ids is null or id = any(p_ids));
$$;

-- ---------------------------------------------------------------- row rules

alter table public.mentions enable row level security;

-- you only ever see your own mentions; changes go through the function above
drop policy if exists mentions_mine on public.mentions;
create policy mentions_mine on public.mentions for select to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------- live updates

do $$ begin
  alter publication supabase_realtime add table public.mentions;
exception when duplicate_object then null; end $$;
