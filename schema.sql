-- CBT Exam Portal schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.exams (
 id uuid primary key default gen_random_uuid(),
 slug text unique not null,
 title text not null,
 duration_seconds integer not null default 5400 check(duration_seconds between 60 and 21600),
 positive_marks numeric(6,2) not null default 1 check(positive_marks >= 0),
 negative_marks numeric(6,2) not null default 0.25 check(negative_marks >= 0),
 published boolean not null default false,
 created_at timestamptz not null default now()
);

create table if not exists public.questions (
 id uuid primary key default gen_random_uuid(),
 exam_id uuid not null references public.exams(id) on delete cascade,
 position integer not null,
 prompt text not null,
 prompt_bn text,
 options jsonb not null check(jsonb_typeof(options)='array' and jsonb_array_length(options)=4),
 options_bn jsonb check(options_bn is null or (jsonb_typeof(options_bn)='array' and jsonb_array_length(options_bn)=4)),
 correct_index integer not null check(correct_index between 0 and 3),
 explanation text,
 unique(exam_id,position)
);

create table if not exists public.candidates (
 id uuid primary key default gen_random_uuid(),
 full_name text not null,
 email text not null,
 created_at timestamptz not null default now()
);

create table if not exists public.attempts (
 id uuid primary key default gen_random_uuid(),
 exam_id uuid not null references public.exams(id),
 candidate_id uuid not null references public.candidates(id),
 started_at timestamptz not null default now(),
 submitted_at timestamptz,
 status text not null default 'in_progress' check(status in ('in_progress','submitted','expired')),
 unique(id,exam_id)
);

create table if not exists public.submissions (
 id uuid primary key default gen_random_uuid(),
 attempt_id uuid unique not null references public.attempts(id),
 exam_id uuid not null references public.exams(id),
 candidate_id uuid not null references public.candidates(id),
 answers jsonb not null default '{}'::jsonb,
 score numeric(8,2) not null,
 correct_count integer not null,
 incorrect_count integer not null,
 unanswered_count integer not null,
 max_marks numeric(8,2) not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 submitted_at timestamptz not null default now(),
 reviewed_at timestamptz,
 reviewed_by uuid references auth.users(id)
);

-- Admin identity is assigned manually in Supabase Auth user metadata:
-- app_metadata: {"role":"admin"}
create or replace function public.is_exam_admin()
returns boolean language sql stable security definer
set search_path = public, auth
as $$ select coalesce((auth.jwt()->'app_metadata'->>'role') = 'admin', false); $$;

alter table public.exams enable row level security;
alter table public.questions enable row level security;
alter table public.candidates enable row level security;
alter table public.attempts enable row level security;
alter table public.submissions enable row level security;

-- Public clients cannot read the answer key or candidate records.
create policy "admins manage exams" on public.exams for all to authenticated
using (public.is_exam_admin()) with check (public.is_exam_admin());
create policy "admins manage questions" on public.questions for all to authenticated
using (public.is_exam_admin()) with check (public.is_exam_admin());
create policy "admins read candidates" on public.candidates for select to authenticated
using (public.is_exam_admin());
create policy "admins read attempts" on public.attempts for select to authenticated
using (public.is_exam_admin());
create policy "admins read submissions" on public.submissions for select to authenticated
using (public.is_exam_admin());
create policy "admins review submissions" on public.submissions for update to authenticated
using (public.is_exam_admin()) with check (public.is_exam_admin());

-- Admin-only view used by the dashboard. Candidate email is visible only to admins.
create or replace view public.admin_submission_view
with (security_invoker = true) as
select s.id, s.status, s.score, s.correct_count, s.incorrect_count,
 s.unanswered_count, s.max_marks, s.submitted_at,
 c.full_name as candidate_name, c.email as candidate_email,
 e.title as exam_title
from public.submissions s
join public.candidates c on c.id=s.candidate_id
join public.exams e on e.id=s.exam_id;

grant select on public.admin_submission_view to authenticated;
grant select, update on public.submissions to authenticated;
grant select on public.candidates, public.attempts to authenticated;
grant select, insert, update, delete on public.exams, public.questions to authenticated;

-- Seed one unpublished General Science exam. Publish only after adding questions.
insert into public.exams(slug,title,duration_seconds,positive_marks,negative_marks,published)
values('general-science','General Science Mock Examination',5400,1,0.25,false)
on conflict(slug) do nothing;
