with secrets as (
    select
        max(decrypted_secret) filter (where name = 'bracket48_project_url') as project_url,
        max(decrypted_secret) filter (where name = 'bracket48_sync_secret') as sync_secret
    from vault.decrypted_secrets
),
request as (
    select net.http_post(
        url := secrets.project_url || '/functions/v1/score-brackets',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-sync-secret', secrets.sync_secret
        ),
        body := jsonb_build_object(
            'dry_run', true,
            'pool_id', '90000000-0000-4000-8000-000000000201',
            'simulation', jsonb_build_object(
                'group_standings', jsonb_build_array(
                    jsonb_build_object('group_id', 'A', 'ordered_team_ids', jsonb_build_array('usa', 'mex', 'can', 'pan')),
                    jsonb_build_object('group_id', 'B', 'ordered_team_ids', jsonb_build_array('eng', 'sco', 'wal', 'irn'))
                ),
                'advancing_third_place_team_ids', jsonb_build_array('can'),
                'knockout_results', jsonb_build_array(
                    jsonb_build_object('match_id', 'r32-1', 'round', 'roundOf32', 'winner_team_id', 'usa'),
                    jsonb_build_object('match_id', 'r16-1', 'round', 'roundOf16', 'winner_team_id', 'arg'),
                    jsonb_build_object('match_id', 'qf-1', 'round', 'quarterfinal', 'winner_team_id', 'bra'),
                    jsonb_build_object('match_id', 'sf-1', 'round', 'semifinal', 'winner_team_id', 'fra'),
                    jsonb_build_object('match_id', 'final', 'round', 'final', 'winner_team_id', 'fra')
                )
            )
        ),
        timeout_milliseconds := 30000
    ) as request_id
    from secrets
)
select
    (response.response).status_code,
    (response.response).body::jsonb->>'scored' as scored,
    (response.response).body::jsonb->>'dry_run' as dry_run,
    (response.response).body::jsonb->>'result_source' as result_source,
    (response.response).body::jsonb->>'score_count' as score_count,
    (response.response).body::jsonb #> '{scores}' as scores
from request
cross join lateral net._http_collect_response(request.request_id, false) as response;
