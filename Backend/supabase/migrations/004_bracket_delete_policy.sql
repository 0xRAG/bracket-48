drop policy if exists "Users can delete unentered own brackets" on public.brackets;
create policy "Users can delete unentered own brackets"
on public.brackets for delete
using (
    user_id = auth.uid()
    and not exists (
        select 1
        from public.pool_entries entry
        where entry.bracket_id = brackets.id
    )
);

notify pgrst, 'reload schema';
