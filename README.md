# Mana Radar — Live MTG LFG

Find local Magic: The Gathering players in real-time. Check in with your
handle and format, share your GPS spot, and see who's nearby within 5 miles.

Live: https://mtggamefinder.netlify.app

## Stack

- One file: `index.html` (no build step — the whole app is this file)
- Tailwind CSS via CDN, Leaflet for maps
- Supabase (Postgres + PostGIS) for check-ins
- Hosted on Netlify (drag-and-drop originally; now auto-deploys from this repo)

## How it works

- A player taps **Check In & Scan Area**, shares GPS, and a row lands in the
  `check_ins` table with a PostGIS `POINT` location.
- The `get_nearby_players` database function returns check-ins within 5 miles
  (8,046.72 m). Active check-ins are from the last 3 hours.
- The header counters show **Active** (last 3 hours) and **Total** (every
  check-in ever, including the daily heartbeat check-ins — see below).
- One check-in per browser every 5 minutes. Handles are capped at 24
  characters, location notes at 80.

## Counters and retention

- `Total` does not count table rows. It reads the `checkin_stats` table
  (one row, `id = 1`), which a database trigger bumps on every insert.
  That way the total survives the cleanup of old rows.
- Check-ins older than **30 days** are deleted daily at 3 AM by a pg_cron
  job. See `supabase/001_stats_and_cleanup.sql`.
- The `checkin_stats` seed in that file captures the historical total as of
  the day it runs, so nothing counted so far is lost.

## Backend pieces (live in Supabase, not in this repo yet)

- `check_ins` table: `player_name`, `format`, `notes`, `location`
  (PostGIS `POINT`), `created_at`.
- `get_nearby_players(user_lat, user_lng, max_meters)` RPC function.
- If you ever reset the Supabase project, copy these from the Supabase
  dashboard (Database → Tables / Functions) into `supabase/` so the
  backend is versioned with the app.

## Daily heartbeat

A scheduled job inserts one check-in a day (around 9:06 AM CT, handle
contains "Muse" or "Cloud") to keep the free-tier Supabase project active.
Those rows count toward the Total by design and show in the app for 3 hours
each morning.

## Security notes

- The Supabase anon key in `index.html` is public by design — it is the
  same key every visitor's browser uses. Row-level security is what
  protects the data: anonymous users can insert and read check-ins, not
  edit or delete them. Verify in Supabase Dashboard → Table Editor →
  `check_ins` → Policies.
- Never commit a `service_role` key anywhere in this repo.

## Deploy

Push to `main` — Netlify auto-deploys the repo (publish directory is the
repo root, no build command).
