-- Diseño normalizado para Supabase/PostgreSQL.
-- La autenticación vive en auth.users; public.profiles la referencia.

create type public.app_role as enum
  ('administrador', 'pastor', 'secretario', 'tesorero', 'coordinador');

create type public.member_status as enum ('activo', 'inactivo');
create type public.event_type as enum ('religioso', 'administrativo');
create type public.event_status as enum ('programado', 'cancelado', 'completado');
create type public.attendance_status as enum ('presente', 'ausente');
create type public.receipt_method as enum
  ('efectivo', 'transferencia', 'tarjeta', 'otro');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role public.app_role not null,
  created_at timestamptz not null default now()
);

create table public.members (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  email text,
  joined_on date not null,
  status public.member_status not null default 'activo',
  deleted_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_type public.event_type not null,
  event_date date not null,
  event_time time not null,
  location text not null,
  description text,
  status public.event_status not null default 'programado',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.event_responsibles (
  event_id uuid not null references public.events(id) on delete cascade,
  member_id uuid not null references public.members(id),
  primary key (event_id, member_id)
);

create table public.attendance (
  event_id uuid not null references public.events(id) on delete cascade,
  member_id uuid not null references public.members(id),
  attendance_date date not null,
  status public.attendance_status not null,
  recorded_by uuid not null references public.profiles(id),
  recorded_at timestamptz not null default now(),
  primary key (event_id, member_id, attendance_date)
);

create table public.ministries (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  coordinator_id uuid references public.members(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ministry_members (
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  joined_on date not null default current_date,
  left_on date,
  primary key (ministry_id, member_id)
);

create table public.ministry_activities (
  id uuid primary key default gen_random_uuid(),
  ministry_id uuid not null references public.ministries(id) on delete cascade,
  title text not null,
  activity_date date not null,
  description text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.financial_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_date date not null,
  amount numeric(12, 2) not null check (amount > 0),
  concept text not null,
  receipt_method public.receipt_method not null,
  is_anonymous boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  published_at timestamptz,
  is_published boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.church_settings (
  id uuid primary key default gen_random_uuid(),
  church_name text not null,
  logo_path text,
  address text,
  contact_phone text,
  contact_email text,
  schedules jsonb not null default '[]'::jsonb,
  institutional_info text,
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  table_name text not null,
  record_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index members_name_idx on public.members using gin (to_tsvector('simple', full_name));
create index events_date_idx on public.events (event_date, status);
create index attendance_date_idx on public.attendance (attendance_date);
create index finance_date_idx on public.financial_transactions (transaction_date);
create index announcements_published_idx on public.announcements (published_at)
  where is_published = true;
