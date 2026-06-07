create or replace function public.preview_pool_invite(invite_code_input text)
returns table (
  id uuid,
  name text,
  invite_code text,
  member_count bigint
)
language sql
security definer
set search_path = public
stable
as $$
  select
    pools.id,
    pools.name,
    pools.invite_code,
    (
      select count(*)
      from public.pool_memberships memberships
      where memberships.pool_id = pools.id
        and memberships.status = 'active'
    ) as member_count
  from public.pools
  where pools.invite_code = upper(trim(invite_code_input))
    and pools.status = 'open'
  limit 1;
$$;

revoke all on function public.preview_pool_invite(text) from public;
grant execute on function public.preview_pool_invite(text) to anon, authenticated;

notify pgrst, 'reload schema';
