# Souqna — Supabase Setup Guide

## Step 1: Create a Supabase project
Go to https://supabase.com and create a new project.

## Step 2: Disable Email Confirmation
Dashboard → Authentication → Providers → Email → **Disable "Confirm email"**

## Step 3: Run Migrations (in order)
Go to Dashboard → SQL Editor and run each file:

| Order | File | What it does |
|-------|------|--------------|
| 1 | `migrations/001_schema.sql` | Creates all tables + indexes |
| 2 | `migrations/002_functions.sql` | Helper functions + triggers (auto-create profile, notifications) |
| 3 | `migrations/003_rls.sql` | All Row Level Security policies |
| 4 | `migrations/004_storage.sql` | Storage buckets + upload policies |
| 5 | `migrations/005_views_increment.sql` | RPC helpers (views, stats) |

## Step 4: Add Environment Variables
In Replit Secrets, add:
```
VITE_SUPABASE_URL     = https://xxxx.supabase.co
VITE_SUPABASE_ANON_KEY = eyJ...
```

## Database Schema

```
profiles          ← linked to auth.users (auto-created on signup)
  └─ products     ← seller_id → profiles
  └─ orders       ← buyer_id + seller_id + product_id
  └─ messages     ← sender_id + receiver_id + product_id (optional)
  └─ notifications← user_id (created by triggers, not client)
```

## RLS Summary

| Table | Who can read | Who can write |
|-------|-------------|---------------|
| profiles | Everyone | Own row only (no type/blocked self-edit) |
| products | Everyone (active only) | Seller owns it; Admin any |
| orders | Buyer + Seller involved + Admin | Buyer places; Seller updates status |
| messages | Sender + Receiver + Admin | Sender inserts; Receiver marks read |
| notifications | Own user + Admin | Server triggers only (no client insert) |

## Storage Buckets

| Bucket | Public | Who uploads |
|--------|--------|-------------|
| product-images | ✅ Yes | Sellers (own folder) |
| avatars | ✅ Yes | Any authenticated user (own folder) |
| receipts | ❌ No | Buyers (own folder, signed URLs) |

## RPC Functions available

- `get_seller_stats(seller_id)` — products, orders, revenue, views
- `get_buyer_stats(buyer_id)` — order counts by status
- `get_unread_counts(user_id)` — messages + notifications badge count
- `increment_product_views(product_id)` — safe view counter
