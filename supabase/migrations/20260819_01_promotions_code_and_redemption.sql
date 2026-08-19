-- ============================================================================
-- FEAT: Promo/Voucher — kode voucher + tracking pemakaian
-- ============================================================================
-- promotions sebelumnya tidak punya kolom untuk kode voucher maupun
-- penghitung pemakaian. Ditambahkan v1 yang mendukung tipe percentage/
-- fixed/voucher (buy_x_get_y & bundle BELUM didukung app — butuh logika
-- substitusi item yang lebih kompleks, dicek lewat Promotion.isSupported
-- di sisi Flutter).

ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS code text;
ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS used_count bigint NOT NULL DEFAULT 0;
CREATE UNIQUE INDEX IF NOT EXISTS promotions_store_code_key ON public.promotions(store_id, code) WHERE code IS NOT NULL;

CREATE OR REPLACE FUNCTION public.find_promotion_by_code(p_store_id uuid, p_code text)
RETURNS public.promotions
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_promo public.promotions;
BEGIN
  IF NOT public.is_store_staff(p_store_id) THEN RAISE EXCEPTION 'Unauthorized store'; END IF;
  SELECT * INTO v_promo FROM public.promotions
    WHERE store_id = p_store_id AND lower(code) = lower(trim(p_code)) AND is_active = true
    AND now() BETWEEN starts_at AND ends_at;
  IF v_promo.id IS NULL THEN RAISE EXCEPTION 'Kode voucher tidak valid atau sudah tidak berlaku'; END IF;
  IF v_promo.usage_limit IS NOT NULL AND v_promo.used_count >= v_promo.usage_limit THEN
    RAISE EXCEPTION 'Kode voucher sudah mencapai batas pemakaian';
  END IF;
  RETURN v_promo;
END; $function$;

CREATE OR REPLACE FUNCTION public.redeem_promotion(p_promotion_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_store_id uuid;
BEGIN
  SELECT store_id INTO v_store_id FROM public.promotions WHERE id = p_promotion_id FOR UPDATE;
  IF v_store_id IS NULL OR NOT public.is_store_staff(v_store_id) THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.promotions SET used_count = used_count + 1
    WHERE id = p_promotion_id AND (usage_limit IS NULL OR used_count < usage_limit);
  IF NOT FOUND THEN RAISE EXCEPTION 'Promo sudah mencapai batas pemakaian'; END IF;
END; $function$;
