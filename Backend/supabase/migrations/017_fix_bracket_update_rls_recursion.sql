create or replace function app_private.has_knockout_for_group_stage_bracket(group_stage_bracket_id_input uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.brackets bracket
        where bracket.phase = 'knockout'
          and bracket.user_id = (select auth.uid())
          and bracket.group_stage_bracket_id = group_stage_bracket_id_input
    );
$$;

revoke all on function app_private.has_knockout_for_group_stage_bracket(uuid) from public;
revoke all on function app_private.has_knockout_for_group_stage_bracket(uuid) from anon;
revoke all on function app_private.has_knockout_for_group_stage_bracket(uuid) from authenticated;
grant execute on function app_private.has_knockout_for_group_stage_bracket(uuid) to authenticated;

drop policy if exists "Users can update own group-stage brackets before knockout" on public.brackets;
create policy "Users can update own group-stage brackets before knockout"
on public.brackets for update
to authenticated
using (
    user_id = (select auth.uid())
    and phase = 'group_stage'
    and not app_private.has_knockout_for_group_stage_bracket(id)
)
with check (
    user_id = (select auth.uid())
    and phase = 'group_stage'
    and group_stage_bracket_id is null
    and not app_private.has_knockout_for_group_stage_bracket(id)
);

notify pgrst, 'reload schema';
