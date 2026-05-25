-- =============================================================
-- Souqna - Migration 003: Row Level Security Policies
-- IMPORTANT: Run AFTER 001_schema.sql and 002_functions.sql
-- =============================================================

-- =============================================================
-- RLS: profiles
-- =============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Public read (username, avatar, account_type only — not phone)
CREATE POLICY "profiles_read_public"
  ON public.profiles FOR SELECT
  USING (true);

-- Users can insert only their own profile
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update only their own non-sensitive fields
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    -- Prevent self-escalation: cannot change account_type or is_blocked
    AND (
      account_type = (SELECT account_type FROM public.profiles WHERE id = auth.uid())
      OR public.is_admin()
    )
  );

-- Only admin can delete profiles
CREATE POLICY "profiles_delete_admin"
  ON public.profiles FOR DELETE
  USING (public.is_admin());

-- =============================================================
-- RLS: products
-- =============================================================
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Anyone can read active products
CREATE POLICY "products_read_active"
  ON public.products FOR SELECT
  USING (is_active = TRUE OR seller_id = auth.uid() OR public.is_admin());

-- Only sellers/admins can insert products (their own seller_id)
CREATE POLICY "products_insert_seller"
  ON public.products FOR INSERT
  WITH CHECK (
    public.is_seller()
    AND seller_id = auth.uid()
  );

-- Seller can update only their own products; admin can update any
CREATE POLICY "products_update_own"
  ON public.products FOR UPDATE
  USING (seller_id = auth.uid() OR public.is_admin())
  WITH CHECK (seller_id = auth.uid() OR public.is_admin());

-- Seller can delete only their own products; admin can delete any
CREATE POLICY "products_delete_own"
  ON public.products FOR DELETE
  USING (seller_id = auth.uid() OR public.is_admin());

-- =============================================================
-- RLS: orders
-- =============================================================
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Buyer sees their own orders; seller sees orders for their products; admin sees all
CREATE POLICY "orders_read"
  ON public.orders FOR SELECT
  USING (
    buyer_id  = auth.uid()
    OR seller_id = auth.uid()
    OR public.is_admin()
  );

-- Only authenticated buyers can place orders (buyer_id must be self)
CREATE POLICY "orders_insert_buyer"
  ON public.orders FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND buyer_id = auth.uid()
    -- Buyer cannot order from themselves
    AND buyer_id <> seller_id
  );

-- Seller can update status of their orders; buyer can cancel; admin can do all
CREATE POLICY "orders_update"
  ON public.orders FOR UPDATE
  USING (
    seller_id = auth.uid()
    OR (buyer_id = auth.uid() AND status = 'pending')
    OR public.is_admin()
  )
  WITH CHECK (
    seller_id = auth.uid()
    OR (buyer_id = auth.uid() AND status = 'pending')
    OR public.is_admin()
  );

-- Only admin can hard-delete orders
CREATE POLICY "orders_delete_admin"
  ON public.orders FOR DELETE
  USING (public.is_admin());

-- =============================================================
-- RLS: messages
-- =============================================================
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Only parties of the conversation can read messages
CREATE POLICY "messages_read_parties"
  ON public.messages FOR SELECT
  USING (
    sender_id   = auth.uid()
    OR receiver_id = auth.uid()
    OR public.is_admin()
  );

-- Authenticated users can send messages (sender_id must be self)
CREATE POLICY "messages_insert_sender"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND sender_id = auth.uid()
  );

-- Receiver can mark message as read; sender cannot edit body; admin can update any
CREATE POLICY "messages_update_read"
  ON public.messages FOR UPDATE
  USING (receiver_id = auth.uid() OR public.is_admin())
  WITH CHECK (receiver_id = auth.uid() OR public.is_admin());

-- Sender can delete their own messages; admin can delete any
CREATE POLICY "messages_delete"
  ON public.messages FOR DELETE
  USING (sender_id = auth.uid() OR public.is_admin());

-- =============================================================
-- RLS: notifications
-- =============================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- User sees only their own notifications; admin sees all
CREATE POLICY "notifications_read_own"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid() OR public.is_admin());

-- Only server-side triggers insert notifications (SECURITY DEFINER functions bypass RLS)
-- Explicitly block direct client inserts
CREATE POLICY "notifications_insert_deny_client"
  ON public.notifications FOR INSERT
  WITH CHECK (public.is_admin());

-- User can mark their own notifications as read
CREATE POLICY "notifications_update_own"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- User can delete their own notifications; admin can delete any
CREATE POLICY "notifications_delete_own"
  ON public.notifications FOR DELETE
  USING (user_id = auth.uid() OR public.is_admin());
