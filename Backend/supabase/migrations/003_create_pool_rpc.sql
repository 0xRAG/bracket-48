create or replace function public.create_pool(
    name_input text,
    type_input public.pool_type,
    invite_code_input text
)
returns public.pools
language plpgsql
security definer
set search_path = public
as $$
declare
    created_pool public.pools;
begin
    if auth.uid() is null then
        raise exception 'Not authenticated';
    end if;

    insert into public.pools (owner_user_id, name, type, invite_code)
    values (
        auth.uid(),
        trim(name_input),
        coalesce(type_input, 'full_tournament'::public.pool_type),
        upper(trim(invite_code_input))
    )
    returning * into created_pool;

    return created_pool;
end;
$$;

grant execute on function public.create_pool(text, public.pool_type, text) to authenticated;

notify pgrst, 'reload schema';
