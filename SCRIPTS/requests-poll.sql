-- ChalkBored Requests — turn it into a poll
-- Run this once in the Supabase SQL editor, AFTER requests.sql.
-- Safe to run again.
--
-- How it works now:
--   the options are set by site mods (in the Requests page, or below)
--   everyone signed in picks ONE option; picking another moves your vote,
--   picking the same one again takes it back
--   mods mark options Planned / Added / Declined, or hide them

-- ---------------------------------------------------------------- only mods add options

create or replace function public.submit_request(p_title text, p_reason text default null, p_kind text default 'game')
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  v_title  text := btrim(coalesce(p_title, ''));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if auth.uid() is null then return 'Sign in first.'; end if;
  if not is_site_mod() then return 'Only moderators can add poll options.'; end if;
  if char_length(v_title) < 3 then return 'Give it a name (3 characters or more).'; end if;
  if char_length(v_title) > 60 then return 'Names max out at 60 characters.'; end if;
  if v_reason is not null and char_length(v_reason) > 140 then return 'Keep the description under 140 characters.'; end if;
  if p_kind not in ('game', 'feature', 'other') then p_kind := 'other'; end if;
  if exists (select 1 from requests where lower(title) = lower(v_title) and not hidden) then
    return 'That option is already in the poll.';
  end if;
  insert into requests (user_id, title, reason, kind, votes) values (null, v_title, v_reason, p_kind, 0);
  return null;
end; $$;

-- ---------------------------------------------------------------- one vote per person

-- Pick an option. Returns null when it worked, or a short reason.
create or replace function public.vote_for(p_request bigint)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare had boolean; touched bigint[];
begin
  if auth.uid() is null then return 'Sign in first.'; end if;
  if is_banned() then return 'Your account is banned.'; end if;
  if not exists (select 1 from requests where id = p_request and not hidden and status in ('open', 'planned')) then
    return 'That option isn''t open for votes.';
  end if;

  select exists (select 1 from request_votes where request_id = p_request and user_id = auth.uid()) into had;

  -- remember every option this person had voted for, then clear them
  select coalesce(array_agg(request_id), '{}') into touched
    from request_votes where user_id = auth.uid();
  delete from request_votes where user_id = auth.uid();

  -- picking the same option again just takes the vote back
  if not had then
    insert into request_votes (request_id, user_id) values (p_request, auth.uid());
    touched := touched || p_request;
  end if;

  update requests r
     set votes = (select count(*) from request_votes v where v.request_id = r.id)
   where r.id = any(touched);
  return null;
end; $$;

-- the old "vote for as many as you like" button is retired
revoke all on function public.toggle_request_vote(bigint) from public, anon, authenticated;

-- people who voted for several options before this keep only their newest vote
delete from public.request_votes v
 using public.request_votes newer
 where newer.user_id = v.user_id and newer.created_at > v.created_at;
update public.requests r set votes = (select count(*) from public.request_votes v where v.request_id = r.id);

-- ---------------------------------------------------------------- the poll options

insert into public.requests (user_id, title, reason, kind, votes)
select null, o.title, o.reason, o.kind, 0
from (values
  ('Site-specific online game', 'A multiplayer game made just for ChalkBored, played online with other people here.', 'game'),
  ('Geometry Dash',             'Jump to the beat and try not to rage.',                                              'game'),
  ('Favorite games',            'Star the games you play most so they stay at the top.',                              'feature')
) as o(title, reason, kind)
where not exists (select 1 from public.requests r where lower(r.title) = lower(o.title));

-- Cookie Clicker is on the site now
update public.requests set status = 'added' where lower(title) = 'cookie clicker';
