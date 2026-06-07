begin;

create extension if not exists pgtap with schema extensions;

select plan(30);

create or replace function pg_temp.login_as(user_id uuid)
returns void
language plpgsql
as $$
begin
    perform set_config('request.jwt.claim.sub', user_id::text, true);
    perform set_config('request.jwt.claim.role', 'authenticated', true);
    perform set_config('request.jwt.claim.aud', 'authenticated', true);
end;
$$;

create or replace function pg_temp.try_insert_pool_entry(
    pool_id_input uuid,
    bracket_id_input uuid,
    user_id_input uuid
)
returns text
language plpgsql
security invoker
as $$
begin
    insert into public.pool_entries (id, pool_id, bracket_id, user_id, phase)
    values (
        gen_random_uuid(),
        pool_id_input,
        bracket_id_input,
        user_id_input,
        'group_stage'::public.bracket_phase
    );

    return 'inserted';
exception
    when insufficient_privilege or check_violation or foreign_key_violation or unique_violation then
        return 'blocked';
end;
$$;

create or replace function pg_temp.try_delete_bracket(bracket_id_input uuid)
returns integer
language plpgsql
security invoker
as $$
declare
    deleted_count integer;
begin
    delete from public.brackets
    where id = bracket_id_input;

    get diagnostics deleted_count = row_count;
    return deleted_count;
end;
$$;

select ok(
    not has_function_privilege('anon', 'public.create_pool(text, public.pool_type)', 'EXECUTE'),
    'anon cannot execute create_pool'
);
select ok(
    not has_function_privilege('anon', 'public.join_pool_by_invite(text)', 'EXECUTE'),
    'anon cannot execute join_pool_by_invite'
);
select ok(
    not has_function_privilege('anon', 'public.preview_pool_invite(text)', 'EXECUTE'),
    'anon cannot execute preview_pool_invite'
);
select ok(
    not has_function_privilege('anon', 'public.set_updated_at()', 'EXECUTE'),
    'anon cannot execute trigger timestamp helper'
);
select ok(
    not has_function_privilege('authenticated', 'public.add_pool_owner_membership()', 'EXECUTE'),
    'authenticated users cannot execute owner-membership trigger helper'
);
select ok(
    has_function_privilege('authenticated', 'public.create_pool(text, public.pool_type)', 'EXECUTE'),
    'authenticated users can execute create_pool'
);
select ok(
    has_function_privilege('authenticated', 'public.join_pool_by_invite(text)', 'EXECUTE'),
    'authenticated users can execute join_pool_by_invite'
);

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
        '00000000-0000-4000-8000-000000000101',
        'authenticated',
        'authenticated',
        'rls-owner@example.test',
        '',
        now(),
        now(),
        now(),
        '{"provider":"test","providers":["test"]}'::jsonb,
        '{}'::jsonb
    ),
    (
        '00000000-0000-4000-8000-000000000102',
        'authenticated',
        'authenticated',
        'rls-member@example.test',
        '',
        now(),
        now(),
        now(),
        '{"provider":"test","providers":["test"]}'::jsonb,
        '{}'::jsonb
    ),
    (
        '00000000-0000-4000-8000-000000000103',
        'authenticated',
        'authenticated',
        'rls-outsider@example.test',
        '',
        now(),
        now(),
        now(),
        '{"provider":"test","providers":["test"]}'::jsonb,
        '{}'::jsonb
    );

insert into public.app_users (id, display_name)
values
    ('00000000-0000-4000-8000-000000000101', 'RLS Owner'),
    ('00000000-0000-4000-8000-000000000102', 'RLS Member'),
    ('00000000-0000-4000-8000-000000000103', 'RLS Outsider');

insert into public.pools (id, owner_user_id, name, invite_code, type, status)
values (
    '10000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'RLS Test Pool',
    'RLSTEST001',
    'full_tournament',
    'open'
);

insert into public.pool_memberships (pool_id, user_id, role, status)
values (
    '10000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000102',
    'member',
    'active'
);

insert into public.brackets (id, user_id, phase, status, display_name, picks)
values
    (
        '20000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000101',
        'group_stage',
        'submitted',
        'Owner entered bracket',
        '{"predictions":[]}'::jsonb
    ),
    (
        '20000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-000000000101',
        'group_stage',
        'submitted',
        'Owner unentered bracket',
        '{"predictions":[]}'::jsonb
    ),
    (
        '20000000-0000-4000-8000-000000000003',
        '00000000-0000-4000-8000-000000000102',
        'group_stage',
        'submitted',
        'Member candidate bracket',
        '{"predictions":[]}'::jsonb
    ),
    (
        '20000000-0000-4000-8000-000000000004',
        '00000000-0000-4000-8000-000000000103',
        'group_stage',
        'submitted',
        'Outsider candidate bracket',
        '{"predictions":[]}'::jsonb
    );

insert into public.pool_entries (id, pool_id, bracket_id, user_id, phase)
values (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'group_stage'
);

insert into public.bracket_scores (
    id,
    pool_entry_id,
    pool_id,
    bracket_id,
    user_id,
    phase,
    group_stage_points,
    knockout_points,
    total_points,
    max_points,
    source_hash
) values (
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000101',
    'group_stage',
    7,
    0,
    7,
    100,
    'rls-test'
);

insert into public.bracket_score_events (
    id,
    bracket_score_id,
    pool_entry_id,
    source_type,
    source_id,
    rule_id,
    points,
    reason
) values (
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'group_stage_prediction',
    'group-a',
    'correct-group-winner',
    4,
    'RLS test score event'
);

set local role authenticated;

select pg_temp.login_as('00000000-0000-4000-8000-000000000101');
select is(
    (select count(*) from public.pools where id = '10000000-0000-4000-8000-000000000001'),
    1::bigint,
    'owner can view their pool'
);
select is(
    (select count(*) from public.pool_memberships where pool_id = '10000000-0000-4000-8000-000000000001'),
    2::bigint,
    'owner can view pool memberships'
);
select is(
    (select count(*) from public.pool_entries where pool_id = '10000000-0000-4000-8000-000000000001'),
    1::bigint,
    'owner can view pool entries'
);
select is(
    (select count(*) from public.brackets where id = '20000000-0000-4000-8000-000000000001'),
    1::bigint,
    'owner can view their entered bracket'
);
select is(
    pg_temp.try_delete_bracket('20000000-0000-4000-8000-000000000001'),
    0,
    'owner cannot delete a bracket after it is entered into a group'
);
select is(
    pg_temp.try_delete_bracket('20000000-0000-4000-8000-000000000002'),
    1,
    'owner can delete an unentered own bracket'
);

select pg_temp.login_as('00000000-0000-4000-8000-000000000102');
select is(
    (select count(*) from public.pools where id = '10000000-0000-4000-8000-000000000001'),
    1::bigint,
    'member can view joined pool'
);
select is(
    (select count(*) from public.pool_memberships where pool_id = '10000000-0000-4000-8000-000000000001'),
    2::bigint,
    'member can view co-members'
);
select is(
    (select count(*) from public.app_users where id in (
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000102'
    )),
    2::bigint,
    'member can view co-member profiles'
);
select is(
    (select count(*) from public.brackets where id = '20000000-0000-4000-8000-000000000001'),
    1::bigint,
    'member can view an entered bracket from their pool'
);
select is(
    (select count(*) from public.bracket_scores where pool_id = '10000000-0000-4000-8000-000000000001'),
    1::bigint,
    'member can view pool leaderboard score'
);
select is(
    (select count(*) from public.bracket_score_events where bracket_score_id = '40000000-0000-4000-8000-000000000001'),
    1::bigint,
    'member can view pool scoring event'
);
select is(
    pg_temp.try_insert_pool_entry(
        '10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000003',
        '00000000-0000-4000-8000-000000000102'
    ),
    'inserted',
    'active member can enter their own bracket'
);

select pg_temp.login_as('00000000-0000-4000-8000-000000000103');
select is(
    (select count(*) from public.pools where id = '10000000-0000-4000-8000-000000000001'),
    0::bigint,
    'non-member cannot view pool'
);
select is(
    (select count(*) from public.pool_memberships where pool_id = '10000000-0000-4000-8000-000000000001'),
    0::bigint,
    'non-member cannot view pool memberships'
);
select is(
    (select count(*) from public.app_users where id in (
        '00000000-0000-4000-8000-000000000101',
        '00000000-0000-4000-8000-000000000102'
    )),
    0::bigint,
    'non-member cannot view pool member profiles'
);
select is(
    (select count(*) from public.pool_entries where pool_id = '10000000-0000-4000-8000-000000000001'),
    0::bigint,
    'non-member cannot view pool entries'
);
select is(
    (select count(*) from public.brackets where id = '20000000-0000-4000-8000-000000000001'),
    0::bigint,
    'non-member cannot view entered bracket'
);
select is(
    (select count(*) from public.bracket_scores where pool_id = '10000000-0000-4000-8000-000000000001'),
    0::bigint,
    'non-member cannot view leaderboard score'
);
select is(
    (select count(*) from public.bracket_score_events where bracket_score_id = '40000000-0000-4000-8000-000000000001'),
    0::bigint,
    'non-member cannot view scoring event'
);
select is(
    pg_temp.try_insert_pool_entry(
        '10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000004',
        '00000000-0000-4000-8000-000000000103'
    ),
    'blocked',
    'non-member cannot enter a bracket into the pool'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
    (select count(*) from public.pools where id = '10000000-0000-4000-8000-000000000001'),
    0::bigint,
    'anon cannot view pools'
);
select is(
    (select count(*) from public.brackets where id = '20000000-0000-4000-8000-000000000001'),
    0::bigint,
    'anon cannot view brackets'
);

select * from finish();

rollback;
