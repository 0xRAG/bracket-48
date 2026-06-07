create or replace function app_private.is_current_user_bracket_for_phase(
    bracket_id_input uuid,
    phase_input public.bracket_phase
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.brackets bracket
        where bracket.id = bracket_id_input
          and bracket.user_id = auth.uid()
          and bracket.phase = phase_input
    );
$$;

revoke all on function app_private.is_current_user_bracket_for_phase(uuid, public.bracket_phase) from public;
revoke all on function app_private.is_current_user_bracket_for_phase(uuid, public.bracket_phase) from anon;
revoke all on function app_private.is_current_user_bracket_for_phase(uuid, public.bracket_phase) from authenticated;
grant execute on function app_private.is_current_user_bracket_for_phase(uuid, public.bracket_phase) to authenticated;

drop policy if exists "Active members can submit own entries" on public.pool_entries;
create policy "Active members can submit own entries"
on public.pool_entries for insert
to authenticated
with check (
    user_id = (select auth.uid())
    and app_private.is_active_pool_member(pool_id, (select auth.uid()))
    and app_private.is_current_user_bracket_for_phase(bracket_id, phase)
);

notify pgrst, 'reload schema';
