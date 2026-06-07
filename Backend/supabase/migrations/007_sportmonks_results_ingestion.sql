create type public.provider_match_status as enum ('scheduled', 'live', 'final', 'postponed', 'canceled', 'unknown');

create table public.provider_teams (
    provider_name text not null,
    provider_team_id bigint not null,
    internal_team_id text,
    name text not null,
    short_code text,
    image_url text,
    is_placeholder boolean not null default false,
    raw_payload jsonb not null default '{}'::jsonb,
    last_synced_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (provider_name, provider_team_id)
);

create table public.tournament_matches (
    id text primary key,
    tournament_id text not null default 'world-cup-2026',
    provider_name text not null,
    provider_fixture_id bigint not null,
    league_id bigint,
    season_id bigint not null,
    stage_id bigint,
    stage_name text,
    provider_group_id bigint,
    group_name text,
    round_id bigint,
    round_name text,
    phase public.bracket_phase not null,
    knockout_round text check (
        knockout_round is null
        or knockout_round in ('round_of_32', 'round_of_16', 'quarterfinal', 'semifinal', 'final', 'third_place')
    ),
    match_number integer,
    fixture_name text not null,
    starts_at timestamptz,
    is_placeholder boolean not null default false,
    home_provider_team_id bigint,
    away_provider_team_id bigint,
    home_team_id text,
    away_team_id text,
    home_slot_label text,
    away_slot_label text,
    status public.provider_match_status not null default 'unknown',
    state_short_name text,
    state_name text,
    home_score integer,
    away_score integer,
    penalty_home_score integer,
    penalty_away_score integer,
    winner_provider_team_id bigint,
    winner_team_id text,
    result_info text,
    raw_payload jsonb not null default '{}'::jsonb,
    last_synced_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (provider_name, provider_fixture_id)
);

create table public.group_standings (
    provider_name text not null,
    tournament_id text not null default 'world-cup-2026',
    season_id bigint not null,
    stage_id bigint,
    provider_group_id bigint not null,
    group_name text not null,
    provider_team_id bigint not null,
    team_id text,
    team_name text not null,
    position integer not null,
    points integer not null default 0,
    played integer,
    won integer,
    drawn integer,
    lost integer,
    goals_for integer,
    goals_against integer,
    goal_difference integer,
    raw_details jsonb not null default '[]'::jsonb,
    raw_payload jsonb not null default '{}'::jsonb,
    last_synced_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (provider_name, season_id, provider_group_id, provider_team_id)
);

create table public.provider_sync_runs (
    id uuid primary key default gen_random_uuid(),
    provider_name text not null,
    sync_type text not null,
    status text not null check (status in ('running', 'succeeded', 'failed')),
    fetched_fixture_count integer not null default 0,
    fetched_standing_count integer not null default 0,
    started_at timestamptz not null default now(),
    finished_at timestamptz,
    error_message text
);

create table public.result_overrides (
    id uuid primary key default gen_random_uuid(),
    match_id text not null references public.tournament_matches (id) on delete cascade,
    corrected_status public.provider_match_status,
    corrected_home_score integer,
    corrected_away_score integer,
    corrected_penalty_home_score integer,
    corrected_penalty_away_score integer,
    corrected_winner_team_id text,
    reason text not null check (char_length(trim(reason)) between 1 and 500),
    is_active boolean not null default true,
    created_by uuid references public.app_users (id) on delete set null,
    created_at timestamptz not null default now()
);

create index provider_teams_internal_team_id_idx on public.provider_teams (internal_team_id);
create index tournament_matches_starts_at_idx on public.tournament_matches (starts_at);
create index tournament_matches_phase_group_idx on public.tournament_matches (phase, group_name);
create index tournament_matches_status_idx on public.tournament_matches (status);
create index group_standings_group_position_idx on public.group_standings (provider_group_id, position);
create index provider_sync_runs_provider_started_idx on public.provider_sync_runs (provider_name, started_at desc);
create index result_overrides_match_active_idx on public.result_overrides (match_id, is_active);

create trigger provider_teams_set_updated_at
before update on public.provider_teams
for each row execute function public.set_updated_at();

create trigger tournament_matches_set_updated_at
before update on public.tournament_matches
for each row execute function public.set_updated_at();

create trigger group_standings_set_updated_at
before update on public.group_standings
for each row execute function public.set_updated_at();

alter table public.provider_teams enable row level security;
alter table public.tournament_matches enable row level security;
alter table public.group_standings enable row level security;
alter table public.provider_sync_runs enable row level security;
alter table public.result_overrides enable row level security;

create policy "Authenticated users can view provider teams"
on public.provider_teams for select
to authenticated
using (true);

create policy "Authenticated users can view tournament matches"
on public.tournament_matches for select
to authenticated
using (true);

create policy "Authenticated users can view group standings"
on public.group_standings for select
to authenticated
using (true);

create policy "Authenticated users can view provider sync runs"
on public.provider_sync_runs for select
to authenticated
using (true);
