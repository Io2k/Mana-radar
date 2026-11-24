-- Mana Radar: permanent total check-ins counter + 30-day retention
-- Run in Supabase Dashboard > SQL Editor for the Mana Radar project
-- (project ref vhpfruffrbdtlysicdds).
--
-- The problem: the Total counter used to count every row in check_ins, so
-- deleting old rows would have wiped the total. This file:
--   1) adds a checkin_stats table (one row, id = 1) seeded with the
--      current total, so every check-in ever -- including the daily
--      heartbeat check-ins -- stays counted;
--   2) adds a trigger that bumps the total on every new check-in;
--   3) schedules a daily cleanup that deletes check-ins older than
--      30 days (active check-ins still expire from view after 3 hours).
--
-- If you run this file twice: the seed and trigger lines are safe to
-- re-run; the last line will say the cleanup job already exists, which
-- is fine, ignore it.

-- 1) Stats table, seeded with the total as it stands today.
create table if not exists public.checkin_stats (
  id integer primary key,
  total_check_ins bigint not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.checkin_stats (id, total_check_ins)
select 1, count(*) from public.check_ins
on conflict (id) do nothing;

-- 2) Trigger: every insert bumps the total by one.
create or replace function public.bump_total_check_ins()
returns trigger
language plpgsql
security definer
as $$
begin
  update public.checkin_stats
    set total_check_ins = total_check_ins + 1,
        updated_at = now()
    where id = 1;
  return new;
end;
$$;

drop trigger if exists check_ins_bump_total on public.check_ins;
create trigger check_ins_bump_total
  after insert on public.check_ins
  for each row execute function public.bump_total_check_ins();

-- 3) Let anonymous visitors read the counter (they already read check_ins).
alter table public.checkin_stats enable row level security;
drop policy if exists "anon can read total" on public.checkin_stats;
create policy "anon can read total"
  on public.checkin_stats for select to anon using (true);

-- 4) Daily cleanup of rows older than 30 days.
-- If this errors, enable the pg_cron extension first: Supabase Dashboard >
-- Database > Extensions > pg_cron, then re-run just this section.
create extension if not exists pg_cron;
select cron.schedule(
  'mana-radar-delete-old-check-ins',
  '0 3 * * *',
  $$ delete from public.check_ins where created_at < now() - interval '30 days' $$
);
