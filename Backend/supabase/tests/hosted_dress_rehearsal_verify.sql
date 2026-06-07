with expected(pool_entry_id, display_name, phase, total_points, max_points, possible_points_remaining, event_count) as (
    values
        ('90000000-0000-4000-8000-000000000401'::uuid, 'Dress Alpha', 'group_stage'::public.bracket_phase, 28, 28, 0, 10),
        ('90000000-0000-4000-8000-000000000402'::uuid, 'Dress Alpha', 'knockout'::public.bracket_phase, 50, 50, 0, 5),
        ('90000000-0000-4000-8000-000000000403'::uuid, 'Dress Beta', 'group_stage'::public.bracket_phase, 18, 28, 0, 6),
        ('90000000-0000-4000-8000-000000000404'::uuid, 'Dress Beta', 'knockout'::public.bracket_phase, 12, 50, 0, 2)
),
actual as (
    select
        score.pool_entry_id,
        app_user.display_name,
        score.phase,
        score.total_points,
        score.max_points,
        score.possible_points_remaining,
        count(event.id)::int as event_count
    from public.bracket_scores score
    join public.app_users app_user
      on app_user.id = score.user_id
    left join public.bracket_score_events event
      on event.pool_entry_id = score.pool_entry_id
    where score.pool_id = '90000000-0000-4000-8000-000000000201'
    group by score.pool_entry_id, app_user.display_name, score.phase, score.total_points, score.max_points, score.possible_points_remaining
)
select
    expected.display_name,
    expected.phase,
    actual.total_points,
    expected.total_points as expected_total_points,
    actual.max_points,
    expected.max_points as expected_max_points,
    actual.possible_points_remaining,
    expected.possible_points_remaining as expected_possible_points_remaining,
    actual.event_count,
    expected.event_count as expected_event_count,
    (
        actual.total_points = expected.total_points
        and actual.max_points = expected.max_points
        and actual.possible_points_remaining = expected.possible_points_remaining
        and actual.event_count = expected.event_count
    ) as passed
from expected
left join actual
  on actual.pool_entry_id = expected.pool_entry_id
order by expected.total_points desc, expected.phase;
