alter table public.app_users
add column if not exists primary_color text not null default 'green'
check (primary_color in ('green', 'purple', 'blue', 'yellow', 'red'));

notify pgrst, 'reload schema';
