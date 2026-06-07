begin;

delete from auth.users
where email like 'dress-rehearsal-%@bracket48.test';

insert into auth.users (
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data
) values
    (
        '90000000-0000-4000-8000-000000000101',
        'authenticated',
        'authenticated',
        'dress-rehearsal-alpha@bracket48.test',
        '',
        now(),
        now(),
        now(),
        '{"provider":"test","providers":["test"]}'::jsonb,
        '{}'::jsonb
    ),
    (
        '90000000-0000-4000-8000-000000000102',
        'authenticated',
        'authenticated',
        'dress-rehearsal-beta@bracket48.test',
        '',
        now(),
        now(),
        now(),
        '{"provider":"test","providers":["test"]}'::jsonb,
        '{}'::jsonb
    );

insert into public.app_users (id, display_name)
values
    ('90000000-0000-4000-8000-000000000101', 'Dress Alpha'),
    ('90000000-0000-4000-8000-000000000102', 'Dress Beta');

insert into public.pools (id, owner_user_id, name, invite_code, type, status)
values (
    '90000000-0000-4000-8000-000000000201',
    '90000000-0000-4000-8000-000000000101',
    'Dress Rehearsal Pool',
    'DRESS48',
    'full_tournament',
    'open'
);

insert into public.pool_memberships (pool_id, user_id, role, status)
values (
    '90000000-0000-4000-8000-000000000201',
    '90000000-0000-4000-8000-000000000102',
    'member',
    'active'
);

insert into public.brackets (id, user_id, phase, status, display_name, picks, submitted_at)
values
    (
        '90000000-0000-4000-8000-000000000301',
        '90000000-0000-4000-8000-000000000101',
        'group_stage',
        'submitted',
        'Dress Alpha Group',
        '{
            "predictions": [
                {"group_id":"A","ordered_team_ids":["usa","mex","can","pan"],"predicted_third_place_advances":true},
                {"group_id":"B","ordered_team_ids":["eng","sco","wal","irn"],"predicted_third_place_advances":false}
            ]
        }'::jsonb,
        now() - interval '10 minutes'
    ),
    (
        '90000000-0000-4000-8000-000000000302',
        '90000000-0000-4000-8000-000000000101',
        'knockout',
        'submitted',
        'Dress Alpha Knockout',
        '{
            "picks": [
                {"match_id":"r32-1","round":"roundOf32","picked_winner_team_id":"usa"},
                {"match_id":"r16-1","round":"roundOf16","picked_winner_team_id":"arg"},
                {"match_id":"qf-1","round":"quarterfinal","picked_winner_team_id":"bra"},
                {"match_id":"sf-1","round":"semifinal","picked_winner_team_id":"fra"},
                {"match_id":"final","round":"final","picked_winner_team_id":"fra"}
            ]
        }'::jsonb,
        now() - interval '9 minutes'
    ),
    (
        '90000000-0000-4000-8000-000000000303',
        '90000000-0000-4000-8000-000000000102',
        'group_stage',
        'submitted',
        'Dress Beta Group',
        '{
            "predictions": [
                {"group_id":"A","ordered_team_ids":["usa","can","mex","pan"],"predicted_third_place_advances":true},
                {"group_id":"B","ordered_team_ids":["eng","sco","wal","irn"],"predicted_third_place_advances":true}
            ]
        }'::jsonb,
        now() - interval '8 minutes'
    ),
    (
        '90000000-0000-4000-8000-000000000304',
        '90000000-0000-4000-8000-000000000102',
        'knockout',
        'submitted',
        'Dress Beta Knockout',
        '{
            "picks": [
                {"match_id":"r32-1","round":"roundOf32","picked_winner_team_id":"usa"},
                {"match_id":"r16-1","round":"roundOf16","picked_winner_team_id":"mex"},
                {"match_id":"qf-1","round":"quarterfinal","picked_winner_team_id":"bra"},
                {"match_id":"sf-1","round":"semifinal","picked_winner_team_id":"arg"},
                {"match_id":"final","round":"final","picked_winner_team_id":"arg"}
            ]
        }'::jsonb,
        now() - interval '7 minutes'
    );

update public.brackets
set group_stage_bracket_id = '90000000-0000-4000-8000-000000000301'
where id = '90000000-0000-4000-8000-000000000302';

update public.brackets
set group_stage_bracket_id = '90000000-0000-4000-8000-000000000303'
where id = '90000000-0000-4000-8000-000000000304';

insert into public.pool_entries (id, pool_id, bracket_id, user_id, phase, submitted_at)
values
    (
        '90000000-0000-4000-8000-000000000401',
        '90000000-0000-4000-8000-000000000201',
        '90000000-0000-4000-8000-000000000301',
        '90000000-0000-4000-8000-000000000101',
        'group_stage',
        now() - interval '6 minutes'
    ),
    (
        '90000000-0000-4000-8000-000000000402',
        '90000000-0000-4000-8000-000000000201',
        '90000000-0000-4000-8000-000000000302',
        '90000000-0000-4000-8000-000000000101',
        'knockout',
        now() - interval '5 minutes'
    ),
    (
        '90000000-0000-4000-8000-000000000403',
        '90000000-0000-4000-8000-000000000201',
        '90000000-0000-4000-8000-000000000303',
        '90000000-0000-4000-8000-000000000102',
        'group_stage',
        now() - interval '4 minutes'
    ),
    (
        '90000000-0000-4000-8000-000000000404',
        '90000000-0000-4000-8000-000000000201',
        '90000000-0000-4000-8000-000000000304',
        '90000000-0000-4000-8000-000000000102',
        'knockout',
        now() - interval '3 minutes'
    );

commit;
