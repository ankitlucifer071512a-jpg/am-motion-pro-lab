create table if not exists public.creative_ai_request_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 0
);

alter table public.creative_ai_request_limits enable row level security;
revoke all on public.creative_ai_request_limits from public, anon, authenticated;

create or replace function public.consume_creative_ai_request(requester_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare allowed boolean;
begin
  insert into public.creative_ai_request_limits as limits
    (user_id, window_started_at, request_count)
  values (requester_id, now(), 1)
  on conflict (user_id) do update set
    window_started_at = case
      when limits.window_started_at < now() - interval '1 hour' then now()
      else limits.window_started_at
    end,
    request_count = case
      when limits.window_started_at < now() - interval '1 hour' then 1
      else limits.request_count + 1
    end
  returning request_count <= 20 into allowed;
  return allowed;
end;
$$;

revoke all on function public.consume_creative_ai_request(uuid) from public, anon, authenticated;
grant execute on function public.consume_creative_ai_request(uuid) to service_role;
