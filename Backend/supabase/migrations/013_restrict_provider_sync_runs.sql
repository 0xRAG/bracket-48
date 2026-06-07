drop policy if exists "Authenticated users can view provider sync runs"
on public.provider_sync_runs;

notify pgrst, 'reload schema';
