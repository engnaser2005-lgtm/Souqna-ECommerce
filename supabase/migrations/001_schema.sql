-- =============================================================
-- Souqna - Migration 001: Schema & Tables
-- Run in Supabase Dashboard → SQL Editor (in order)
-- =============================================================

-- ===== EXTENSIONS =====
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================
-- TABLE: profiles
-- =============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username      TEXT UNIQUE NOT NULL,
  account_type  TEXT NOT NULL DEFAULT 'buyer'
                  CHECK (account_type IN ('buyer', 'seller', 'admin')),
  avatar_url    TEXT,
  phone         TEXT,
  is_blocked    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- TABLE: products
-- =============================================================
CREATE TABLE IF NOT EXISTS public.products (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title          TEXT NOT NULL,
  description    TEXT,
  price          NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
  original_price NUMERIC(12, 2) CHECK (original_price >= 0),
  category       TEXT NOT NULL,
  images         TEXT[] NOT NULL DEFAULT '{}',
  stock          INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  badge          TEXT CHECK (badge IN ('new', 'sale', 'featured', 'bestseller', NULL)),
  views          INTEGER NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- TABLE: orders
-- =============================================================
CREATE TABLE IF NOT EXISTS public.orders (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  buyer_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  seller_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  product_id   UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity     INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price   NUMERIC(12, 2) NOT NULL,
  total_price  NUMERIC(12, 2) NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
  receipt_url  TEXT,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- TABLE: messages
-- =============================================================
CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  UUID REFERENCES public.products(id) ON DELETE SET NULL,
  sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body        TEXT NOT NULL CHECK (length(body) > 0),
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT no_self_message CHECK (sender_id <> receiver_id)
);

-- =============================================================
-- TABLE: notifications
-- =============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type      TEXT NOT NULL
              CHECK (type IN ('order_placed', 'order_updated', 'message', 'product_approved', 'admin', 'system')),
  title     TEXT NOT NULL,
  body      TEXT,
  is_read   BOOLEAN NOT NULL DEFAULT FALSE,
  ref_id    UUID,
  ref_type  TEXT CHECK (ref_type IN ('order', 'message', 'product', NULL)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- INDEXES
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_products_seller_id    ON public.products(seller_id);
CREATE INDEX IF NOT EXISTS idx_products_category     ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_active    ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_orders_buyer_id       ON public.orders(buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller_id      ON public.orders(seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_product_id     ON public.orders(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_status         ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id    ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id  ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_product_id   ON public.messages(product_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
