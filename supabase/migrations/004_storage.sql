-- =============================================================
-- Souqna - Migration 004: Storage Buckets & Policies
-- =============================================================

-- =============================================================
-- BUCKETS
-- =============================================================

-- product-images: public read, seller/admin write
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  TRUE,
  5242880,  -- 5 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- avatars: public read, owner write
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  TRUE,
  2097152,  -- 2 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- receipts: private, buyer/seller/admin read
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'receipts',
  'receipts',
  FALSE,
  10485760,  -- 10 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- =============================================================
-- STORAGE POLICIES: product-images
-- =============================================================

-- Public read
CREATE POLICY "product_images_read_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');

-- Sellers/admins can upload to their own folder (path starts with their user id)
CREATE POLICY "product_images_insert_seller"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND auth.uid() IS NOT NULL
    AND public.is_seller()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Owner or admin can update/replace their images
CREATE POLICY "product_images_update_owner"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'product-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_admin()
    )
  );

-- Owner or admin can delete their images
CREATE POLICY "product_images_delete_owner"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'product-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_admin()
    )
  );

-- =============================================================
-- STORAGE POLICIES: avatars
-- =============================================================

-- Public read
CREATE POLICY "avatars_read_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Authenticated users can upload to their own folder
CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Owner can update their avatar
CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Owner or admin can delete avatars
CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_admin()
    )
  );

-- =============================================================
-- STORAGE POLICIES: receipts
-- =============================================================

-- Only the uploader (buyer) or the related seller, or admin, can read
CREATE POLICY "receipts_read_parties"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'receipts'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_admin()
    )
  );

-- Authenticated buyers can upload receipts to their folder
CREATE POLICY "receipts_insert_buyer"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'receipts'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Owner or admin can delete receipts
CREATE POLICY "receipts_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'receipts'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_admin()
    )
  );
