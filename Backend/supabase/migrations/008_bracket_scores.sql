create table public.bracket_scores (
    id uuid primary key default gen_random_uuid(),
    pool_entry_id uuid not null references public.pool_entries (id) on delete cascade,
    pool_id uuid not null references public.pools (id) on delete cascade,
    bracket_id uuid not null references public.brackets (id) on delete cascade,
    user_id uuid not null references public.app_users (id) on delete cascade,
    phase public.bracket_phase not null,
    group_stage_points integer not null default 0,
    knockout_points integer not null default 0,
    total_points integer not null default 0,
    max_points integer not null default 0,
    scoring_version text not null default 'world-cup-default-v1',
    source_hash text not null,
    calculated_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (pool_entry_id)
);

create table public.bracket_score_events (
    id uuid primary key default gen_random_uuid(),
    bracket_score_id uuid not null references public.bracket_scores (id) on delete cascade,
    pool_entry_id uuid not null references public.pool_entries (id) on delete cascade,
    source_type text not null check (source_type in ('group_stage_prediction', 'knockout_pick')),
    source_id text not null,
    rule_id text not null,
    points integer not null,
    reason text not null,
    created_at timestamptz not null default now()
);

create index bracket_scores_pool_total_idx on public.bracket_scores (pool_id, total_points desc, calculated_at asc);
create index bracket_scores_user_idx on public.bracket_scores (user_id);
create index bracket_score_events_pool_entry_idx on public.bracket_score_events (pool_entry_id);

create trigger bracket_scores_set_updated_at
before update on public.bracket_scores
for each row execute function public.set_updated_at();

alter table public.bracket_scores enable row level security;
alter table public.bracket_score_events enable row level security;

create policy "Pool members can view bracket scores"
on public.bracket_scores for select
to authenticated
using (
    user_id = auth.uid()
    or exists (
        select 1
        from public.pool_memberships membership
        where membership.pool_id = bracket_scores.pool_id
          and membership.user_id = auth.uid()
          and membership.status = 'active'
    )
);

create policy "Pool members can view bracket score events"
on public.bracket_score_events for select
to authenticated
using (
    exists (
        select 1
        from public.bracket_scores score
        join public.pool_memberships membership
          on membership.pool_id = score.pool_id
         and membership.user_id = auth.uid()
         and membership.status = 'active'
        where score.id = bracket_score_events.bracket_score_id
    )
);

notify pgrst, 'reload schema';
