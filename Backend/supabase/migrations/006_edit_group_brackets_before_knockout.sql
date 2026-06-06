create policy "Users can update own group-stage brackets before knockout"
on public.brackets for update
using (
    user_id = auth.uid()
    and phase = 'group_stage'
    and not exists (
        select 1
        from public.brackets knockout
        where knockout.user_id = auth.uid()
          and knockout.phase = 'knockout'
          and knockout.group_stage_bracket_id = brackets.id
    )
)
with check (
    user_id = auth.uid()
    and phase = 'group_stage'
    and group_stage_bracket_id is null
    and not exists (
        select 1
        from public.brackets knockout
        where knockout.user_id = auth.uid()
          and knockout.phase = 'knockout'
          and knockout.group_stage_bracket_id = brackets.id
    )
);
