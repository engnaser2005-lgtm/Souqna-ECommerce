-- =============================================================
-- Souqna - Migration 002: Functions & Triggers
-- =============================================================

-- ===== Helper: get account_type for a user =====
CREATE OR REPLACE FUNCTION public.get_account_type(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT account_type FROM public.profiles WHERE id = p_user_id;
$$;

-- ===== Helper: check if calling user is admin =====
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND account_type = 'admin'
  );
$$;

-- ===== Helper: check if calling user is seller =====
CREATE OR REPLACE FUNCTION public.is_seller()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND account_type IN ('seller', 'admin')
  );
$$;

-- ===== Trigger: auto-update updated_at =====
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ===== Trigger: auto-create profile on auth signup =====
-- This ensures a profile row is always created when a user registers.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, account_type, phone)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      'user_' || substr(NEW.id::text, 1, 8)
    ),
    COALESCE(NEW.raw_user_meta_data->>'account_type', 'buyer'),
    NEW.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===== Trigger: auto-create order notification =====
CREATE OR REPLACE FUNCTION public.notify_on_order()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_product_title TEXT;
BEGIN
  SELECT title INTO v_product_title FROM public.products WHERE id = NEW.product_id;

  -- Notify buyer
  INSERT INTO public.notifications (user_id, type, title, body, ref_id, ref_type)
  VALUES (
    NEW.buyer_id,
    'order_placed',
    'تم استلام طلبك',
    'طلبك على منتج "' || v_product_title || '" قيد المراجعة',
    NEW.id,
    'order'
  );

  -- Notify seller
  INSERT INTO public.notifications (user_id, type, title, body, ref_id, ref_type)
  VALUES (
    NEW.seller_id,
    'order_placed',
    'طلب جديد على منتجك',
    'لديك طلب جديد على منتج "' || v_product_title || '"',
    NEW.id,
    'order'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_notification ON public.orders;
CREATE TRIGGER trg_order_notification
  AFTER INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_order();

-- ===== Trigger: notify on order status change =====
CREATE OR REPLACE FUNCTION public.notify_on_order_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_product_title TEXT;
  v_status_label TEXT;
BEGIN
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  SELECT title INTO v_product_title FROM public.products WHERE id = NEW.product_id;

  v_status_label := CASE NEW.status
    WHEN 'confirmed'  THEN 'تم تأكيد'
    WHEN 'shipped'    THEN 'تم شحن'
    WHEN 'delivered'  THEN 'تم تسليم'
    WHEN 'cancelled'  THEN 'تم إلغاء'
    ELSE 'تم تحديث'
  END;

  INSERT INTO public.notifications (user_id, type, title, body, ref_id, ref_type)
  VALUES (
    NEW.buyer_id,
    'order_updated',
    v_status_label || ' طلبك',
    'تم تحديث حالة طلبك على "' || v_product_title || '" إلى: ' || NEW.status,
    NEW.id,
    'order'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_status_notification ON public.orders;
CREATE TRIGGER trg_order_status_notification
  AFTER UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_order_update();

-- ===== Trigger: notify on new message =====
CREATE OR REPLACE FUNCTION public.notify_on_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  SELECT username INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;

  INSERT INTO public.notifications (user_id, type, title, body, ref_id, ref_type)
  VALUES (
    NEW.receiver_id,
    'message',
    'رسالة جديدة من ' || v_sender_name,
    substr(NEW.body, 1, 100),
    NEW.id,
    'message'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_message_notification ON public.messages;
CREATE TRIGGER trg_message_notification
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_message();
