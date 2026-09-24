-- ChalkBored Requests — three starter ideas so the board isn't empty
-- Run this once in the Supabase SQL editor, AFTER requests.sql.
-- Safe to run again: it skips any that are already there.
-- They show as posted "by ChalkBored" and start at 0 votes.
-- To change them, edit the titles/reasons below before running.

insert into public.requests (user_id, title, reason, kind, votes)
select null, v.title, v.reason, v.kind, 0
from (values
  ('Cookie Clicker', 'Click the cookie, buy grandmas, never stop.', 'game'),
  ('Geometry Dash',  'Jump to the beat and try not to rage.',      'game'),
  ('Favorite games', 'Star the games you play most so they stay at the top.', 'feature')
) as v(title, reason, kind)
where not exists (
  select 1 from public.requests r where lower(r.title) = lower(v.title)
);
