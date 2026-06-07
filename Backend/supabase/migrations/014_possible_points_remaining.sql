alter table public.bracket_scores
add column if not exists possible_points_remaining integer not null default 0;

create index if not exists bracket_scores_pool_possible_idx
on public.bracket_scores (pool_id, possible_points_remaining desc);

notify pgrst, 'reload schema';
