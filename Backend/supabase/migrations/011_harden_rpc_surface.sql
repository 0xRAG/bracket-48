create schema if not exists app_private;

grant usage on schema app_private to authenticated;

create or replace function app_private.is_active_pool_member(pool_id_input uuid, user_id_input uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.pool_memberships membership
        where membership.pool_id = pool_id_input
          and membership.user_id = user_id_input
          and membership.status = 'active'
    );
$$;

revoke all on function app_private.is_active_pool_member(uuid, uuid) from public;
revoke all on function app_private.is_active_pool_member(uuid, uuid) from anon;
revoke all on function app_private.is_active_pool_member(uuid, uuid) from authenticated;
grant execute on function app_private.is_active_pool_member(uuid, uuid) to authenticated;

alter function public.set_updated_at() set search_path = public;

revoke all on function public.set_updated_at() from public;
revoke all on function public.set_updated_at() from anon;
revoke all on function public.set_updated_at() from authenticated;

revoke all on function public.add_pool_owner_membership() from public;
revoke all on function public.add_pool_owner_membership() from anon;
revoke all on function public.add_pool_owner_membership() from authenticated;

drop function if exists public.create_pool(text, public.pool_type, text);

create or replace function public.create_pool(
    name_input text,
    type_input public.pool_type
)
returns public.pools
language plpgsql
security definer
set search_path = public
as $$
declare
    created_pool public.pools;
    current_user_id uuid := auth.uid();
    generated_invite_code text;
    attempt integer;
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    for attempt in 1..5 loop
        generated_invite_code := upper(encode(gen_random_bytes(6), 'hex'));

        begin
            insert into public.pools (owner_user_id, name, type, invite_code)
            values (
                current_user_id,
                trim(name_input),
                coalesce(type_input, 'full_tournament'::public.pool_type),
                generated_invite_code
            )
            returning * into created_pool;

            return created_pool;
        exception
            when unique_violation then
                null;
        end;
    end loop;

    raise exception 'Could not create invite code';
end;
$$;

revoke all on function public.create_pool(text, public.pool_type) from public;
revoke all on function public.create_pool(text, public.pool_type) from anon;
revoke all on function public.create_pool(text, public.pool_type) from authenticated;
grant execute on function public.create_pool(text, public.pool_type) to authenticated;

create or replace function public.join_pool_by_invite(invite_code_input text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    matched_pool_id uuid;
    current_user_id uuid := auth.uid();
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select pools.id into matched_pool_id
    from public.pools
    where pools.invite_code = upper(trim(invite_code_input))
      and pools.status = 'open';

    if matched_pool_id is null then
        raise exception 'Invite code not found';
    end if;

    insert into public.pool_memberships (pool_id, user_id, role, status)
    values (matched_pool_id, current_user_id, 'member', 'active')
    on conflict (pool_id, user_id) do update
    set status = 'active';

    return matched_pool_id;
end;
$$;

revoke all on function public.join_pool_by_invite(text) from public;
revoke all on function public.join_pool_by_invite(text) from anon;
revoke all on function public.join_pool_by_invite(text) from authenticated;
grant execute on function public.join_pool_by_invite(text) to authenticated;

revoke all on function public.preview_pool_invite(text) from public;
revoke all on function public.preview_pool_invite(text) from anon;
revoke all on function public.preview_pool_invite(text) from authenticated;
grant execute on function public.preview_pool_invite(text) to authenticated;

drop policy if exists "Pool members can view pools" on public.pools;
create policy "Pool members can view pools"
on public.pools for select
to authenticated
using (app_private.is_active_pool_member(id, (select auth.uid())));

drop policy if exists "Members can view pool memberships" on public.pool_memberships;
create policy "Members can view pool memberships"
on public.pool_memberships for select
to authenticated
using (
    user_id = (select auth.uid())
    or app_private.is_active_pool_member(pool_id, (select auth.uid()))
);

drop policy if exists "Pool members can view entries" on public.pool_entries;
create policy "Pool members can view entries"
on public.pool_entries for select
to authenticated
using (
    user_id = (select auth.uid())
    or app_private.is_active_pool_member(pool_id, (select auth.uid()))
);

drop policy if exists "Active members can submit own entries" on public.pool_entries;
create policy "Active members can submit own entries"
on public.pool_entries for insert
to authenticated
with check (
    user_id = (select auth.uid())
    and app_private.is_active_pool_member(pool_id, (select auth.uid()))
    and exists (
        select 1
        from public.brackets bracket
        where bracket.id = pool_entries.bracket_id
          and bracket.user_id = (select auth.uid())
          and bracket.phase = pool_entries.phase
    )
);

drop policy if exists "Pool members can view co-member profiles" on public.app_users;
create policy "Pool members can view co-member profiles"
on public.app_users for select
to authenticated
using (
    id = (select auth.uid())
    or exists (
        select 1
        from public.pool_memberships membership
        where membership.user_id = app_users.id
          and membership.status = 'active'
          and app_private.is_active_pool_member(membership.pool_id, (select auth.uid()))
    )
);

drop policy if exists "Pool members can view entered brackets" on public.brackets;
create policy "Pool members can view entered brackets"
on public.brackets for select
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.pool_entries entry
        where entry.bracket_id = brackets.id
          and app_private.is_active_pool_member(entry.pool_id, (select auth.uid()))
    )
);

drop function if exists public.is_active_pool_member(uuid, uuid);

notify pgrst, 'reload schema';
