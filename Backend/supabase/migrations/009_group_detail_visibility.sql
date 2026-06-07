create policy "Pool members can view co-member profiles"
on public.app_users for select
to authenticated
using (
    id = auth.uid()
    or exists (
        select 1
        from public.pool_memberships membership
        where membership.user_id = app_users.id
          and membership.status = 'active'
          and public.is_active_pool_member(membership.pool_id, auth.uid())
    )
);

create policy "Pool members can view entered brackets"
on public.brackets for select
to authenticated
using (
    user_id = auth.uid()
    or exists (
        select 1
        from public.pool_entries entry
        where entry.bracket_id = brackets.id
          and public.is_active_pool_member(entry.pool_id, auth.uid())
    )
);

notify pgrst, 'reload schema';
