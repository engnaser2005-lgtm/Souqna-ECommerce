# Souqna - سوقنا

متجر إلكتروني احترافي باللغة العربية مع تصميم RTL كامل وهوية بصرية موحدة.

## Run & Operate

- `pnpm --filter @workspace/souqna run dev` — run the frontend (port assigned automatically)
- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- Required env (for Supabase): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- Frontend: React + Vite + React Router v6
- Auth/DB: Supabase (client-side)
- State: React Context (AuthContext) + TanStack Query
- Styling: Tailwind CSS + custom CSS with Arabic RTL
- Fonts: Tajawal + Cairo (Google Fonts)
- Build: esbuild (CJS bundle)

## Where things live

```
artifacts/souqna/src/
  components/       — Shared UI components (Header, UserDropdown, ...)
  pages/            — Page-level components (Home, Login, Register, ...)
  services/         — Supabase service layer
    supabaseClient.ts     — client + isSupabaseConfigured
    authService.ts        — signUp / signIn / signOut / session
    profileService.ts     — profiles table CRUD
    productService.ts     — products table CRUD + storage upload
    orderService.ts       — orders table CRUD + receipt upload
    messageService.ts     — messages CRUD + realtime subscription
    notificationService.ts— notifications CRUD + realtime subscription
    storageService.ts     — generic storage upload/remove/signed-URL
  types/
    auth.ts               — AccountType, Profile, PERMISSIONS, hasPermission()
    database.ts           — All DB row types, payloads, filters
  contexts/         — AuthContext (session + profile + role helpers)
  hooks/            — useAuth, useProfile, useRole
  routes/           — AppRouter, ProtectedRoute, RoleGuard
  layouts/          — MainLayout
  utils/            — constants.ts, formatters.ts, cn.ts
supabase/
  migrations/
    001_schema.sql        — Tables: profiles, products, orders, messages, notifications
    002_functions.sql     — Triggers: auto-profile, notifications, updated_at
    003_rls.sql           — Row Level Security for all tables
    004_storage.sql       — Buckets: product-images, avatars, receipts + policies
    005_views_increment.sql — RPC: seller stats, buyer stats, unread counts
  SETUP.md                — Step-by-step Supabase setup guide
```

## Architecture decisions

- RTL direction set globally via `html { direction: rtl; }` — all layouts are Arabic-first
- Supabase client degrades gracefully when env vars aren't set (shows warning, no crash)
- AuthContext: session + user + profile + role booleans (isSeller, isAdmin, can())
- Profile auto-created by DB trigger `on_auth_user_created` AND by client `profileService.ensureProfile()`
- Notifications created server-side by SECURITY DEFINER triggers — no client INSERT allowed
- ProtectedRoute → requires auth; RoleGuard → requires specific account_type
- React Router `basename` uses `import.meta.env.BASE_URL` for correct path handling behind proxy
- Storage path convention: `{userId}/{timestamp}.{ext}` — RLS enforces userId prefix match

## Database Schema

```
profiles          ← linked to auth.users (auto-created on signup trigger)
  └── products    ← seller_id → profiles(id)
  └── orders      ← buyer_id + seller_id + product_id
  └── messages    ← sender_id + receiver_id + product_id (optional)
  └── notifications ← user_id (INSERT blocked for clients, triggers only)
```

## RLS Security Model

| Table | Read | Insert | Update | Delete |
|-------|------|--------|--------|--------|
| profiles | Everyone | Own only | Own (no type escalation) | Admin only |
| products | All (active); own (any) | Seller (own seller_id) | Own / Admin | Own / Admin |
| orders | Buyer+Seller+Admin | Buyer (buyer≠seller) | Seller/Admin; Buyer cancel | Admin only |
| messages | Parties + Admin | Sender (sender=self) | Receiver (mark read) | Sender / Admin |
| notifications | Own + Admin | Admin / Triggers only | Own (mark read) | Own / Admin |

## Brand Identity

| Token | Value |
|-------|-------|
| Background | `#041C3A` |
| Header | `#02152d` |
| Gold (primary accent) | `#D4AF37` |
| Card | `#06264D` |
| Secondary | `#0b2f5c` |
| Text secondary | `#dddddd` |

## Product

متجر إلكتروني عربي يدعم: عرض المنتجات، الفئات، العروض، نظام مستخدمين (قادم)، الدفع (قادم)، لوحة الإدارة (قادمة).

## User preferences

- مشروع عربي RTL بالكامل
- الألوان الرسمية محددة في variables.css وindex.css
- كل Component في ملف مستقل
- React Router v6 (لا wouter)
- Supabase للـ auth والـ database

## Gotchas

- `VITE_SUPABASE_URL` و `VITE_SUPABASE_ANON_KEY` مطلوبان لتفعيل المصادقة
- لا تستخدم `wouter` — المشروع يستخدم `react-router-dom`
- إضافة الصفحات المحمية داخل `<ProtectedRoute>` في `AppRouter.tsx`
- إضافة روابط التنقل في مصفوفة `NAV_LINKS` داخل `Header.tsx`

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
