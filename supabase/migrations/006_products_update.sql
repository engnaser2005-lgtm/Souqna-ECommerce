-- =============================================================
-- Souqna - Migration 006: Products table - extended columns
-- Run after 001_schema.sql (or on fresh install, include in 001)
-- =============================================================

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS city              TEXT,
  ADD COLUMN IF NOT EXISTS contact_number    TEXT,
  ADD COLUMN IF NOT EXISTS condition         TEXT DEFAULT 'new'
                             CHECK (condition IN ('new', 'used', 'like_new')),
  ADD COLUMN IF NOT EXISTS featured          BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS discount_percentage INTEGER NOT NULL DEFAULT 0
                             CHECK (discount_percentage BETWEEN 0 AND 100),
  ADD COLUMN IF NOT EXISTS inquiries_count   INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS orders_count      INTEGER NOT NULL DEFAULT 0;

-- Update the seller stats RPC to include new fields
CREATE OR REPLACE FUNCTION public.get_seller_stats(p_seller_id UUID)
RETURNS TABLE(
  total_products    BIGINT,
  active_products   BIGINT,
  total_orders      BIGINT,
  pending_orders    BIGINT,
  total_revenue     NUMERIC,
  total_views       BIGINT,
  total_inquiries   BIGINT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    COUNT(DISTINCT p.id)                                              AS total_products,
    COUNT(DISTINCT p.id) FILTER (WHERE p.is_active = TRUE)           AS active_products,
    COALESCE(SUM(p.orders_count), 0)::BIGINT                        AS total_orders,
    COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'pending')         AS pending_orders,
    COALESCE(SUM(o.total_price) FILTER (WHERE o.status = 'delivered'), 0) AS total_revenue,
    COALESCE(SUM(p.views), 0)                                        AS total_views,
    COALESCE(SUM(p.inquiries_count), 0)::BIGINT                     AS total_inquiries
  FROM public.products p
  LEFT JOIN public.orders o ON o.product_id = p.id AND o.seller_id = p_seller_id
  WHERE p.seller_id = p_seller_id;
$$;

-- Index for city and featured
CREATE INDEX IF NOT EXISTS idx_products_city     ON public.products(city);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(featured);
