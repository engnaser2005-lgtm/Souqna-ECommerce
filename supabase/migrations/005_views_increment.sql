-- =============================================================
-- Souqna - Migration 005: Helper RPC Functions
-- =============================================================

-- Safely increment product view count (avoids RLS write conflict)
CREATE OR REPLACE FUNCTION public.increment_product_views(p_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE public.products
  SET views = views + 1
  WHERE id = p_id AND is_active = TRUE;
$$;

-- Get unread counts for a user (single query, used in notification badge)
CREATE OR REPLACE FUNCTION public.get_unread_counts(p_user_id UUID)
RETURNS TABLE(messages_count BIGINT, notifications_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    (SELECT COUNT(*) FROM public.messages
     WHERE receiver_id = p_user_id AND is_read = FALSE) AS messages_count,
    (SELECT COUNT(*) FROM public.notifications
     WHERE user_id = p_user_id AND is_read = FALSE) AS notifications_count;
$$;

-- Get seller dashboard stats
CREATE OR REPLACE FUNCTION public.get_seller_stats(p_seller_id UUID)
RETURNS TABLE(
  total_products    BIGINT,
  active_products   BIGINT,
  total_orders      BIGINT,
  pending_orders    BIGINT,
  total_revenue     NUMERIC,
  total_views       BIGINT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    COUNT(DISTINCT p.id)                                          AS total_products,
    COUNT(DISTINCT p.id) FILTER (WHERE p.is_active = TRUE)       AS active_products,
    COUNT(DISTINCT o.id)                                          AS total_orders,
    COUNT(DISTINCT o.id) FILTER (WHERE o.status = 'pending')     AS pending_orders,
    COALESCE(SUM(o.total_price) FILTER (WHERE o.status = 'delivered'), 0) AS total_revenue,
    COALESCE(SUM(p.views), 0)                                    AS total_views
  FROM public.products p
  LEFT JOIN public.orders o ON o.product_id = p.id
  WHERE p.seller_id = p_seller_id;
$$;

-- Get buyer dashboard stats
CREATE OR REPLACE FUNCTION public.get_buyer_stats(p_buyer_id UUID)
RETURNS TABLE(
  total_orders      BIGINT,
  pending_orders    BIGINT,
  delivered_orders  BIGINT,
  cancelled_orders  BIGINT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    COUNT(*)                                                          AS total_orders,
    COUNT(*) FILTER (WHERE status = 'pending')                       AS pending_orders,
    COUNT(*) FILTER (WHERE status = 'delivered')                     AS delivered_orders,
    COUNT(*) FILTER (WHERE status = 'cancelled')                     AS cancelled_orders
  FROM public.orders
  WHERE buyer_id = p_buyer_id;
$$;
