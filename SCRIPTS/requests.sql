-- ChalkBored Requests — vote for what gets added next
-- Run this once in the Supabase SQL editor, AFTER supabase-schema.sql.
-- Safe to run again; it skips anything already there.
--
-- How it works:
--   anyone signed in to Chalk Chat can suggest something (3 an hour, max)
--   one upvote per person per suggestion; you can take it back
--   the chat's blocked words and timeouts apply here too
--   site mods set a status (open / planned / added / declined) or hide one

-- ---------------------------------------------------------------- shared with chat auto mod
-- (already there if you ran chat-automod.sql; created here if not)

alter table public.profiles add column if not exists muted_until timestamptz;

create table if not exists public.blocked_words (
  word text primary key check (char_length(word) between 2 and 40)
);
alter table public.blocked_words enable row level security;

-- ---------------------------------------------------------------- tables

create table if not exists public.requests (
  id         bigserial primary key,
  user_id    uuid references public.profiles on delete set null,
  title      text not null check (char_length(title) between 3 and 60),
  reason     text check (reason is null or char_length(reason) <= 140),
  kind       text not null default 'game' check (kind in ('game', 'feature', 'other')),
  status     text not null default 'open' check (status in ('open', 'planned', 'added', 'declined')),
  hidden     boolean not null default false,
  votes      int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists requests_votes_idx on public.requests (votes desc, created_at desc);

create table if not exists public.request_votes (
  request_id bigint references public.requests on delete cascade,
  user_id    uuid references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, user_id)
);

-- ---------------------------------------------------------------- helpers

-- true if the text has a blocked word, catching swaps like 3 for e
create or replace function public.has_blocked_word(p_text text)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1 from blocked_words w
    where translate(lower(coalesce(p_text, '')), '0134578@$!', 'oieastbasi') ~ ('\m' || w.word || '\M')
  );
$$;

-- only the functions below use it; the site can't test words against the list
revoke all on function public.has_blocked_word(text) from public, anon, authenticated;

-- ---------------------------------------------------------------- actions

-- Suggest something. Returns null when it worked, or a short reason when not.
create or replace function public.submit_request(p_title text, p_reason text default null, p_kind text default 'game')
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  me       profiles;
  v_title  text := btrim(coalesce(p_title, ''));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  recent   int;
  new_id   bigint;
begin
  if auth.uid() is null then return 'Sign in first.'; end if;
  select * into me from profiles where id = auth.uid();
  if me.id is null then return 'Your account isn''t set up yet.'; end if;
  if me.banned then return 'Your account is banned.'; end if;
  if me.muted_until is not null and me.muted_until > now() then return 'You''re timed out right now.'; end if;

  if char_length(v_title) < 3 then return 'Give it a name (3 characters or more).'; end if;
  if char_length(v_title) > 60 then return 'Names max out at 60 characters.'; end if;
  if v_reason is not null and char_length(v_reason) > 140 then return 'Keep the reason under 140 characters.'; end if;
  if p_kind not in ('game', 'feature', 'other') then p_kind := 'other'; end if;

  if not is_site_mod() then
    select count(*) into recent from requests where user_id = me.id and created_at > now() - interval '1 hour';
    if recent >= 3 then return 'That''s 3 this hour. Try again later.'; end if;
    if has_blocked_word(v_title) or has_blocked_word(v_reason) then return 'That has a blocked word in it.'; end if;
  end if;

  if exists (select 1 from requests where lower(title) = lower(v_title) and not hidden) then
    return 'Someone already asked for that. Find it and vote for it instead.';
  end if;

  insert into requests (user_id, title, reason, kind, votes) values (me.id, v_title, v_reason, p_kind, 1)
  returning id into new_id;
  insert into request_votes (request_id, user_id) values (new_id, me.id);
  return null;
end; $$;

-- Vote, or take your vote back. Returns the new count (or -1 if you can't vote).
create or replace function public.toggle_request_vote(p_request bigint)
returns int language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  if auth.uid() is null or is_banned() then return -1; end if;
  if not exists (select 1 from requests where id = p_request and not hidden) then return -1; end if;

  if exists (select 1 from request_votes where request_id = p_request and user_id = auth.uid()) then
    delete from request_votes where request_id = p_request and user_id = auth.uid();
  else
    insert into request_votes (request_id, user_id) values (p_request, auth.uid());
  end if;

  select count(*) into n from request_votes where request_id = p_request;
  update requests set votes = n where id = p_request;
  return n;
end; $$;

-- Site mods: set the status, hide, or unhide.
create or replace function public.set_request_status(p_request bigint, p_status text, p_hidden boolean default null)
returns text language plpgsql security definer set search_path = public, extensions as $$
begin
  if not is_site_mod() then return 'Moderators only.'; end if;
  if p_status is not null and p_status not in ('open', 'planned', 'added', 'declined') then return 'Unknown status.'; end if;
  update requests
     set status = coalesce(p_status, status),
         hidden = coalesce(p_hidden, hidden)
   where id = p_request;
  return null;
end; $$;

-- ---------------------------------------------------------------- row rules

alter table public.requests      enable row level security;
alter table public.request_votes enable row level security;

-- everyone signed in sees what isn't hidden; mods see everything
drop policy if exists requests_read on public.requests;
create policy requests_read on public.requests for select to authenticated
  using (not hidden or is_site_mod());

-- you can see your own votes (so the page knows what you voted for)
drop policy if exists request_votes_mine on public.request_votes;
create policy request_votes_mine on public.request_votes for select to authenticated
  using (user_id = auth.uid());

-- no insert/update/delete policies: everything goes through the functions above

-- ---------------------------------------------------------------- live updates

do $$ begin
  alter publication supabase_realtime add table public.requests;
exception when duplicate_object then null; end $$;
