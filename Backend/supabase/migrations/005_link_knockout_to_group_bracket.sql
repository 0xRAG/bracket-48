alter table public.brackets
add column if not exists group_stage_bracket_id uuid references public.brackets (id) on delete restrict;

create index if not exists brackets_group_stage_bracket_id_idx
on public.brackets (group_stage_bracket_id);

notify pgrst, 'reload schema';
