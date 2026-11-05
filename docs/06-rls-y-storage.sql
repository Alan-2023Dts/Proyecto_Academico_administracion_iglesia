-- Ejecutar después de 03-modelo-datos.sql en el SQL Editor de Supabase.
-- Estas políticas son la autoridad real de autorización; la UI solo mejora UX.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'full_name', ''),
      split_part(new.email, '@', 1)
    ),
    new.email
  );
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, email)
select
  id,
  coalesce(
    nullif(raw_user_meta_data->>'full_name', ''),
    split_part(email, '@', 1)
  ),
  email
from auth.users
where email is not null
on conflict (id) do nothing;

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.user_roles where user_id = auth.uid();
$$;

revoke all on function public.current_app_role() from public;
grant execute on function public.current_app_role() to authenticated;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.members enable row level security;
alter table public.events enable row level security;
alter table public.event_responsibles enable row level security;
alter table public.attendance enable row level security;
alter table public.ministries enable row level security;
alter table public.ministry_members enable row level security;
alter table public.ministry_activities enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.announcements enable row level security;
alter table public.church_settings enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists profiles_self_read on public.profiles;
drop policy if exists profiles_admin_update on public.profiles;
drop policy if exists roles_admin_manage on public.user_roles;
drop policy if exists roles_self_read on public.user_roles;
drop policy if exists members_read on public.members;
drop policy if exists members_manage on public.members;
drop policy if exists events_read on public.events;
drop policy if exists events_manage on public.events;
drop policy if exists event_responsibles_read on public.event_responsibles;
drop policy if exists event_responsibles_manage on public.event_responsibles;
drop policy if exists attendance_read on public.attendance;
drop policy if exists attendance_manage on public.attendance;
drop policy if exists ministries_read on public.ministries;
drop policy if exists ministries_manage on public.ministries;
drop policy if exists ministry_members_read on public.ministry_members;
drop policy if exists ministry_members_manage on public.ministry_members;
drop policy if exists ministry_activities_read on public.ministry_activities;
drop policy if exists ministry_activities_manage on public.ministry_activities;
drop policy if exists finance_authorized_read on public.financial_transactions;
drop policy if exists finance_authorized_insert on public.financial_transactions;
drop policy if exists finance_authorized_update on public.financial_transactions;
drop policy if exists announcements_read on public.announcements;
drop policy if exists announcements_manage on public.announcements;
drop policy if exists settings_read on public.church_settings;
drop policy if exists settings_admin_manage on public.church_settings;
drop policy if exists audit_read_admin on public.audit_log;
drop policy if exists audit_insert_authenticated on public.audit_log;

create policy profiles_self_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.current_app_role() in ('administrador', 'pastor'));

create policy profiles_admin_update on public.profiles
  for update to authenticated
  using (public.current_app_role() = 'administrador')
  with check (public.current_app_role() = 'administrador');

create policy roles_admin_manage on public.user_roles
  for all to authenticated
  using (public.current_app_role() = 'administrador')
  with check (public.current_app_role() = 'administrador');

create policy roles_self_read on public.user_roles
  for select to authenticated
  using (user_id = auth.uid());

create policy members_read on public.members
  for select to authenticated
  using (deleted_at is null or public.current_app_role() in ('administrador', 'pastor'));

create policy members_manage on public.members
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'secretario'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'secretario'));

create policy events_read on public.events
  for select to authenticated
  using (true);

create policy events_manage on public.events
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'secretario', 'coordinador'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'secretario', 'coordinador'));

create policy event_responsibles_read on public.event_responsibles
  for select to authenticated using (true);

create policy event_responsibles_manage on public.event_responsibles
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'secretario'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'secretario'));

create policy attendance_read on public.attendance
  for select to authenticated using (true);

create policy attendance_manage on public.attendance
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'secretario', 'coordinador'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'secretario', 'coordinador'));

create policy ministries_read on public.ministries
  for select to authenticated using (true);

create policy ministries_manage on public.ministries
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'coordinador'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'coordinador'));

create policy ministry_members_read on public.ministry_members
  for select to authenticated using (true);

create policy ministry_members_manage on public.ministry_members
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'coordinador'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'coordinador'));

create policy ministry_activities_read on public.ministry_activities
  for select to authenticated using (true);

create policy ministry_activities_manage on public.ministry_activities
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'coordinador'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'coordinador'));

create policy finance_authorized_read on public.financial_transactions
  for select to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'tesorero'));

create policy finance_authorized_insert on public.financial_transactions
  for insert to authenticated
  with check (
    public.current_app_role() in ('administrador', 'tesorero')
    and created_by = auth.uid()
  );

create policy finance_authorized_update on public.financial_transactions
  for update to authenticated
  using (public.current_app_role() in ('administrador', 'tesorero'))
  with check (public.current_app_role() in ('administrador', 'tesorero'));

create policy announcements_read on public.announcements
  for select to authenticated
  using (is_published = true or public.current_app_role() in ('administrador', 'pastor', 'secretario'));

create policy announcements_manage on public.announcements
  for all to authenticated
  using (public.current_app_role() in ('administrador', 'pastor', 'secretario'))
  with check (public.current_app_role() in ('administrador', 'pastor', 'secretario'));

create policy settings_read on public.church_settings
  for select to authenticated using (true);

create policy settings_admin_manage on public.church_settings
  for all to authenticated
  using (public.current_app_role() = 'administrador')
  with check (public.current_app_role() = 'administrador' and updated_by = auth.uid());

create policy audit_read_admin on public.audit_log
  for select to authenticated
  using (public.current_app_role() = 'administrador');

create policy audit_insert_authenticated on public.audit_log
  for insert to authenticated
  with check (actor_id = auth.uid());

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  old_record jsonb;
  new_record jsonb;
begin
  old_record := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  new_record := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;
  insert into public.audit_log (
    actor_id, action, table_name, record_id, metadata
  )
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    case
      when coalesce(new_record, old_record) ? 'id'
      then (coalesce(new_record, old_record)->>'id')::uuid
      else null
    end,
    jsonb_build_object(
      'old', old_record,
      'new', new_record
    )
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.write_audit_log() from public;

drop trigger if exists audit_members on public.members;
create trigger audit_members after insert or update or delete on public.members
  for each row execute function public.write_audit_log();
drop trigger if exists audit_events on public.events;
create trigger audit_events after insert or update or delete on public.events
  for each row execute function public.write_audit_log();
drop trigger if exists audit_attendance on public.attendance;
create trigger audit_attendance after insert or update or delete on public.attendance
  for each row execute function public.write_audit_log();
drop trigger if exists audit_ministries on public.ministries;
create trigger audit_ministries after insert or update or delete on public.ministries
  for each row execute function public.write_audit_log();
drop trigger if exists audit_ministry_members on public.ministry_members;
create trigger audit_ministry_members after insert or update or delete on public.ministry_members
  for each row execute function public.write_audit_log();
drop trigger if exists audit_ministry_activities on public.ministry_activities;
create trigger audit_ministry_activities after insert or update or delete on public.ministry_activities
  for each row execute function public.write_audit_log();
drop trigger if exists audit_financial_transactions on public.financial_transactions;
create trigger audit_financial_transactions after insert or update or delete on public.financial_transactions
  for each row execute function public.write_audit_log();
drop trigger if exists audit_announcements on public.announcements;
create trigger audit_announcements after insert or update or delete on public.announcements
  for each row execute function public.write_audit_log();
drop trigger if exists audit_church_settings on public.church_settings;
create trigger audit_church_settings after insert or update or delete on public.church_settings
  for each row execute function public.write_audit_log();

insert into storage.buckets (id, name, public)
values ('church-assets', 'church-assets', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists church_assets_read on storage.objects;
drop policy if exists church_assets_admin_insert on storage.objects;
drop policy if exists church_assets_admin_update on storage.objects;
drop policy if exists church_assets_admin_delete on storage.objects;

create policy church_assets_read on storage.objects
  for select to public
  using (bucket_id = 'church-assets');

create policy church_assets_admin_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'church-assets'
    and public.current_app_role() = 'administrador'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy church_assets_admin_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'church-assets'
    and public.current_app_role() = 'administrador'
    and owner_id = auth.uid()::text
  );

create policy church_assets_admin_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'church-assets'
    and public.current_app_role() = 'administrador'
    and owner_id = auth.uid()::text
  );
