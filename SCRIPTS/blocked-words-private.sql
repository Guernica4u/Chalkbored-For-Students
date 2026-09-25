-- ChalkBored: keep the blocked words list inside Supabase only
-- Run this once in the Supabase SQL editor. Safe to run again, and safe to
-- run before or after chat-automod.sql / requests.sql.
--
-- After this, nothing on the site can read or change the list, not even a
-- moderator's browser. Auto mod still uses it (that happens inside the
-- database). To see or edit the words: Supabase -> Table Editor -> blocked_words.

do $$ begin
  -- nobody reads the list through the site
  if to_regclass('public.blocked_words') is not null then
    execute 'drop policy if exists blocked_words_read on public.blocked_words';
    execute 'alter table public.blocked_words enable row level security';
  end if;

  -- nobody changes the list through the site
  if to_regprocedure('public.set_blocked_word(text, boolean)') is not null then
    execute 'revoke all on function public.set_blocked_word(text, boolean) from public, anon, authenticated';
  end if;

  -- nobody can test words against the list one by one from the site
  if to_regprocedure('public.has_blocked_word(text)') is not null then
    execute 'revoke all on function public.has_blocked_word(text) from public, anon, authenticated';
  end if;
end $$;
