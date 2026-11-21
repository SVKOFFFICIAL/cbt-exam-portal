# CBT Exam Portal

A deployable public General Science CBT portal with candidate registration, timed attempts, server-side scoring, admin review and result approval.

## Stack
- React + Vite frontend
- Supabase Postgres, Auth and Edge Functions
- Vercel static hosting

## 1. Create Supabase project
Create a project at https://supabase.com. In SQL Editor, run `supabase/schema.sql`.

## 2. Add questions
In Supabase Table Editor, open `exams` and copy the UUID for `general-science`.
Insert question rows into `questions` with:
- `exam_id`: the exam UUID
- `position`: 1, 2, 3...
- `prompt`: English question
- `prompt_bn`: optional Bengali question
- `options`: JSON array of exactly four English options
- `options_bn`: optional JSON array of four Bengali options
- `correct_index`: 0, 1, 2 or 3

Example `options`: `["Oxygen","Nitrogen","Carbon dioxide","Hydrogen"]`
Example `options_bn`: `["অক্সিজেন","নাইট্রোজেন","কার্বন ডাই-অক্সাইড","হাইড্রোজেন"]`

When questions are ready, set `exams.published = true`. Set `duration_seconds`, `positive_marks`, and `negative_marks` as desired.

## 3. Configure admin
In Supabase Authentication, create your admin user. Then assign this app metadata to that user:
```json
{"role":"admin"}
```
Use the Supabase dashboard/admin API to set **app_metadata**, not user-editable `user_metadata`. The admin dashboard uses email/password sign-in. Do not make candidates admin users.

## 4. Deploy Edge Functions
Install Supabase CLI and link your project:
```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT.supabase.co SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase functions deploy start-exam
supabase functions deploy submit-exam
```
The service-role key must only exist as a Supabase secret. Never put it in `.env`, frontend code, GitHub, or Vercel.

## 5. Run locally
```bash
npm install
cp .env.example .env
```
Put your Supabase Project URL and **anon/publishable key** in `.env`, then:
```bash
npm run dev
```

## 6. Deploy frontend to Vercel
Push this folder to a private GitHub repository, import it into Vercel, and set:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Build command: `npm run build`
Output directory: `dist`

`vercel.json` enables client-side route fallback. The public exam URL is:
`https://YOUR-DOMAIN.vercel.app/?exam=general-science`

## Result approval workflow
Candidate submission is scored in the `submit-exam` Edge Function. The answer key is not returned by `start-exam`. Scores remain `pending`; admins can approve or reject them in the dashboard. The dashboard's approved/pending lists read the admin-only `admin_submission_view`.

## Important production checklist
- Add your real questions and test the exam before publishing.
- Configure Supabase Auth email/password and an admin account.
- Add rate limiting / CAPTCHA to public start-exam to reduce spam.
- Set up Supabase backups and review retention/deletion rules for candidate names and emails.
- Configure your own privacy notice and contact details.
- Test expiry, duplicate submissions, concurrent requests and mobile layouts.
- Consider email verification or a one-attempt policy if the exam has high-stakes use.

This is a starter implementation. Before a high-stakes or large public exam, add stronger anti-abuse controls, server-side timer enforcement with an explicit expiry submission flow, audit logs, and independent security review.
