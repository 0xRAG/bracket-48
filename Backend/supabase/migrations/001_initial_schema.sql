create extension if not exists pgcrypto;

create type public.pool_type as enum ('full_tournament', 'knockout_only');
create type public.pool_status as enum ('open', 'locked', 'archived');
create type public.pool_role as enum ('owner', 'member');
create type public.membership_status as enum ('active', 'removed');
create type public.bracket_phase as enum ('group_stage', 'knockout');
create type public.bracket_status as enum ('draft', 'submitted', 'locked');

create table public.app_users (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.pools (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null references public.app_users (id) on delete cascade,
    name text not null check (char_length(trim(name)) between 1 and 80),
    invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{4,12}$'),
    type public.pool_type not null default 'full_tournament',
    status public.pool_status not null default 'open',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table public.pool_memberships (
    pool_id uuid not null references public.pools (id) on delete cascade,
    user_id uuid not null references public.app_users (id) on delete cascade,
    role public.pool_role not null default 'member',
    status public.membership_status not null default 'active',
    joined_at timestamptz not null default now(),
    primary key (pool_id, user_id)
);

create table public.brackets (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.app_users (id) on delete cascade,
    phase public.bracket_phase not null,
    status public.bracket_status not null default 'submitted',
    display_name text not null,
    picks jsonb not null,
    submitted_at timestamptz not null default now(),
    locked_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint brackets_picks_object check (jsonb_typeof(picks) = 'object')
);

create table public.pool_entries (
    id uuid primary key default gen_random_uuid(),
    pool_id uuid not null references public.pools (id) on delete cascade,
    bracket_id uuid not null references public.brackets (id) on delete cascade,
    user_id uuid not null references public.app_users (id) on delete cascade,
    phase public.bracket_phase not null,
    submitted_at timestamptz not null default now(),
    unique (pool_id, user_id, phase),
    unique (pool_id, bracket_id)
);

create index pool_memberships_user_id_idx on public.pool_memberships (user_id);
create index brackets_user_id_phase_idx on public.brackets (user_id, phase);
create index pool_entries_user_id_idx on public.pool_entries (user_id);
create index pool_entries_bracket_id_idx on public.pool_entries (bracket_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger app_users_set_updated_at
before update on public.app_users
for each row execute function public.set_updated_at();

create trigger pools_set_updated_at
before update on public.pools
for each row execute function public.set_updated_at();

create trigger brackets_set_updated_at
before update on public.brackets
for each row execute function public.set_updated_at();

create or replace function public.add_pool_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.pool_memberships (pool_id, user_id, role, status)
    values (new.id, new.owner_user_id, 'owner', 'active')
    on conflict (pool_id, user_id) do update
    set role = 'owner', status = 'active';

    return new;
end;
$$;

create trigger pools_add_owner_membership
after insert on public.pools
for each row execute function public.add_pool_owner_membership();

create or replace function public.join_pool_by_invite(invite_code_input text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    matched_pool_id uuid;
begin
    select pools.id into matched_pool_id
    from public.pools
    where pools.invite_code = upper(trim(invite_code_input))
      and pools.status = 'open';

    if matched_pool_id is null then
        raise exception 'Invite code not found';
    end if;

    insert into public.pool_memberships (pool_id, user_id, role, status)
    values (matched_pool_id, auth.uid(), 'member', 'active')
    on conflict (pool_id, user_id) do update
    set status = 'active';

    return matched_pool_id;
end;
$$;

grant execute on function public.join_pool_by_invite(text) to authenticated;

alter table public.app_users enable row level security;
alter table public.pools enable row level security;
alter table public.pool_memberships enable row level security;
alter table public.brackets enable row level security;
alter table public.pool_entries enable row level security;

create policy "Users can view themselves"
on public.app_users for select
using (id = auth.uid());

create policy "Users can insert themselves"
on public.app_users for insert
with check (id = auth.uid());

create policy "Users can update themselves"
on public.app_users for update
using (id = auth.uid())
with check (id = auth.uid());

create policy "Pool members can view pools"
on public.pools for select
using (
    exists (
        select 1
        from public.pool_memberships membership
        where membership.pool_id = pools.id
          and membership.user_id = auth.uid()
          and membership.status = 'active'
    )
);

create policy "Authenticated users can create pools they own"
on public.pools for insert
with check (owner_user_id = auth.uid());

create policy "Pool owners can update pools"
on public.pools for update
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

create policy "Members can view pool memberships"
on public.pool_memberships for select
using (
    user_id = auth.uid()
    or exists (
        select 1
        from public.pool_memberships viewer
        where viewer.pool_id = pool_memberships.pool_id
          and viewer.user_id = auth.uid()
          and viewer.status = 'active'
    )
);

create policy "Users can view own brackets"
on public.brackets for select
using (user_id = auth.uid());

create policy "Users can submit own brackets"
on public.brackets for insert
with check (user_id = auth.uid());

create policy "Users can update own draft brackets"
on public.brackets for update
using (user_id = auth.uid() and status = 'draft')
with check (user_id = auth.uid());

create policy "Pool members can view entries"
on public.pool_entries for select
using (
    user_id = auth.uid()
    or exists (
        select 1
        from public.pool_memberships membership
        where membership.pool_id = pool_entries.pool_id
          and membership.user_id = auth.uid()
          and membership.status = 'active'
    )
);

create policy "Active members can submit own entries"
on public.pool_entries for insert
with check (
    user_id = auth.uid()
    and exists (
        select 1
        from public.pool_memberships membership
        where membership.pool_id = pool_entries.pool_id
          and membership.user_id = auth.uid()
          and membership.status = 'active'
    )
    and exists (
        select 1
        from public.brackets bracket
        where bracket.id = pool_entries.bracket_id
          and bracket.user_id = auth.uid()
          and bracket.phase = pool_entries.phase
    )
);
