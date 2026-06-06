create or replace function public.is_active_pool_member(pool_id_input uuid, user_id_input uuid)
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

grant execute on function public.is_active_pool_member(uuid, uuid) to authenticated;

drop policy if exists "Pool members can view pools" on public.pools;
create policy "Pool members can view pools"
on public.pools for select
using (public.is_active_pool_member(id, auth.uid()));

drop policy if exists "Members can view pool memberships" on public.pool_memberships;
create policy "Members can view pool memberships"
on public.pool_memberships for select
using (
    user_id = auth.uid()
    or public.is_active_pool_member(pool_id, auth.uid())
);

drop policy if exists "Pool members can view entries" on public.pool_entries;
create policy "Pool members can view entries"
on public.pool_entries for select
using (
    user_id = auth.uid()
    or public.is_active_pool_member(pool_id, auth.uid())
);

drop policy if exists "Active members can submit own entries" on public.pool_entries;
create policy "Active members can submit own entries"
on public.pool_entries for insert
with check (
    user_id = auth.uid()
    and public.is_active_pool_member(pool_id, auth.uid())
    and exists (
        select 1
        from public.brackets bracket
        where bracket.id = pool_entries.bracket_id
          and bracket.user_id = auth.uid()
          and bracket.phase = pool_entries.phase
    )
);

notify pgrst, 'reload schema';
