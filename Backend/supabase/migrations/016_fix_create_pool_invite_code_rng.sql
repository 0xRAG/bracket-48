create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create or replace function public.create_pool(
    name_input text,
    type_input public.pool_type
)
returns public.pools
language plpgsql
security definer
set search_path = public, extensions
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

notify pgrst, 'reload schema';
