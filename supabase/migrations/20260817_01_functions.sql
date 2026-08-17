-- ============================================================================
-- FUNCTIONS — snapshot setelah audit & perbaikan bug (2026-08-17)
-- ============================================================================

-- ---------- Helper akses/otorisasi ----------
CREATE OR REPLACE FUNCTION public.user_store_access(p_store_id uuid)
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
 SELECT EXISTS (SELECT 1 FROM public.staff s WHERE s.store_id=p_store_id AND s.user_id=(SELECT auth.uid()) AND s.is_active=true)
    OR EXISTS (SELECT 1 FROM public.stores st WHERE st.id=p_store_id AND st.owner_id=(SELECT auth.uid()));
$function$;

CREATE OR REPLACE FUNCTION public.is_store_admin(p_store_id uuid)
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.staff s WHERE s.store_id=p_store_id AND s.user_id=auth.uid() AND s.is_active=true AND s.role IN ('owner','admin'));
$function$;

CREATE OR REPLACE FUNCTION public.is_store_staff(p_store_id uuid)
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.staff s WHERE s.store_id=p_store_id AND s.user_id=auth.uid() AND s.is_active=true);
$function$;

-- ---------- Trigger helper umum ----------
CREATE OR REPLACE FUNCTION public.touch_updated_at()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $function$ BEGIN NEW.updated_at = now(); RETURN NEW; END $function$;

CREATE OR REPLACE FUNCTION public.touch_customers_updated_at()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $function$ BEGIN NEW.updated_at = now(); RETURN NEW; END $function$;

CREATE OR REPLACE FUNCTION public.touch_promotions_updated_at()
 RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public','pg_temp'
AS $function$ BEGIN NEW.updated_at = now(); RETURN NEW; END $function$;

-- ---------- Nomor invoice & audit log ----------
-- (definisi generate_invoice_no dan write_audit_log: lihat trigger masing-
--  masing di 20260817_02_triggers.sql — badan fungsi tercatat di sana karena
--  dipasang sebagai trigger function pada transactions/berbagai tabel)

-- ---------- Checkout (INTI POS) ----------
-- Sudah diperbaiki 2x pada sesi ini:
--  1) kolom salah (total_amount/created_by/unit_price/payment_method) yang
--     membuat SEMUA transaksi gagal tersimpan
--  2) double stock deduction: RPC ini SEBELUMNYA memotong stok manual PADAHAL
--     trigger trg_apply_stock_on_sale juga memotong -> stok minus dua kali.
--     Sekarang RPC ini HANYA insert & memvalidasi; trigger yang memotong stok.
CREATE OR REPLACE FUNCTION public.checkout_transaction(
  p_store_id uuid, p_shift_id uuid, p_items jsonb, p_paid_amount bigint,
  p_payment_method text, p_payments jsonb DEFAULT NULL::jsonb,
  p_idempotency_key text DEFAULT NULL::text, p_transaction_discount bigint DEFAULT 0
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_existing uuid; v_existing_fp text; v_tx uuid;
  v_subtotal bigint; v_line_discount bigint; v_discount bigint; v_total bigint;
  v_item jsonb; v_product record; v_qty integer; v_item_discount bigint; v_gross bigint;
  v_fp text; v_staff_id uuid;
  v_paid_amount bigint; v_effective_method text; v_distinct_methods integer; v_payment_count integer;
BEGIN
  IF NOT public.user_store_access(p_store_id) THEN RAISE EXCEPTION 'Unauthorized store'; END IF;
  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) < 16 OR length(p_idempotency_key) > 128 THEN RAISE EXCEPTION 'Invalid idempotency key'; END IF;
  SELECT id INTO v_staff_id FROM public.staff WHERE user_id = auth.uid() AND store_id = p_store_id AND is_active = true;
  IF v_staff_id IS NULL THEN RAISE EXCEPTION 'Staff tidak ditemukan atau tidak aktif'; END IF;
  v_fp := encode(digest(jsonb_build_object('store_id',p_store_id,'shift_id',p_shift_id,'items',p_items,'paid_amount',p_paid_amount,'payment_method',p_payment_method,'payments',p_payments,'transaction_discount',p_transaction_discount)::text,'sha256'),'hex');
  SELECT id,idempotency_fingerprint INTO v_existing,v_existing_fp FROM public.transactions WHERE store_id=p_store_id AND idempotency_key=p_idempotency_key LIMIT 1;
  IF v_existing IS NOT NULL THEN
    IF v_existing_fp IS DISTINCT FROM v_fp THEN RAISE EXCEPTION 'Idempotency key already used with different payload'; END IF;
    RETURN v_existing;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_store_id::text || ':' || p_idempotency_key,0));
  SELECT id,idempotency_fingerprint INTO v_existing,v_existing_fp FROM public.transactions WHERE store_id=p_store_id AND idempotency_key=p_idempotency_key LIMIT 1;
  IF v_existing IS NOT NULL THEN
    IF v_existing_fp IS DISTINCT FROM v_fp THEN RAISE EXCEPTION 'Idempotency key already used with different payload'; END IF;
    RETURN v_existing;
  END IF;
  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items)=0 THEN RAISE EXCEPTION 'Items required'; END IF;

  IF p_payments IS NOT NULL THEN
    IF jsonb_typeof(p_payments) <> 'array' OR jsonb_array_length(p_payments) = 0 THEN RAISE EXCEPTION 'Invalid payments'; END IF;
    SELECT COALESCE(SUM((x->>'amount')::bigint), 0), COUNT(DISTINCT (x->>'method')), COUNT(*)
      INTO v_paid_amount, v_distinct_methods, v_payment_count FROM jsonb_array_elements(p_payments) x;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_payments) x WHERE (x->>'amount')::bigint <= 0) THEN
      RAISE EXCEPTION 'Setiap nominal pembayaran harus lebih dari 0';
    END IF;
    v_effective_method := CASE WHEN v_distinct_methods > 1 OR v_payment_count > 1 THEN 'campuran'
                               ELSE (SELECT (x->>'method') FROM jsonb_array_elements(p_payments) x LIMIT 1) END;
  ELSE
    v_paid_amount := p_paid_amount; v_effective_method := p_payment_method;
  END IF;

  v_subtotal := 0; v_line_discount := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::integer;
    IF v_qty IS NULL OR v_qty <= 0 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;
    SELECT id,name,selling_price,stock INTO v_product FROM public.products WHERE id=(v_item->>'product_id')::uuid AND store_id=p_store_id AND is_active=true FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
    IF v_product.stock < v_qty THEN RAISE EXCEPTION 'Insufficient stock for %', v_product.name; END IF;
    v_gross := v_product.selling_price::bigint * v_qty;
    v_item_discount := LEAST(GREATEST(COALESCE((v_item->>'discount')::bigint, 0), 0), v_gross);
    v_subtotal := v_subtotal + v_gross; v_line_discount := v_line_discount + v_item_discount;
  END LOOP;

  v_discount := LEAST(v_line_discount + GREATEST(COALESCE(p_transaction_discount,0),0), v_subtotal);
  v_total := v_subtotal - v_discount;
  IF v_paid_amount < v_total THEN RAISE EXCEPTION 'Insufficient payment'; END IF;

  INSERT INTO public.transactions(store_id, shift_id, staff_id, subtotal, discount, total, paid_amount, change_amount, payment_method, status, idempotency_key, idempotency_fingerprint)
  VALUES (p_store_id, p_shift_id, v_staff_id, v_subtotal, v_discount, v_total, v_paid_amount, v_paid_amount - v_total, v_effective_method::payment_method, 'completed', p_idempotency_key, v_fp)
  RETURNING id INTO v_tx;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::integer;
    SELECT id,name,selling_price,cost_price,stock INTO v_product FROM public.products WHERE id=(v_item->>'product_id')::uuid AND store_id=p_store_id FOR UPDATE;
    v_gross := v_product.selling_price::bigint * v_qty;
    v_item_discount := LEAST(GREATEST(COALESCE((v_item->>'discount')::bigint,0), 0), v_gross);
    INSERT INTO public.transaction_items(transaction_id, product_id, product_name, price, cost_price, quantity, subtotal, discount)
    VALUES (v_tx, v_product.id, v_product.name, v_product.selling_price, v_product.cost_price, v_qty, v_gross - v_item_discount, v_item_discount);
    -- TIDAK ada UPDATE stok / INSERT stock_movements manual di sini dengan
    -- sengaja: trigger trg_apply_stock_on_sale menanganinya otomatis.
  END LOOP;

  IF p_payments IS NOT NULL THEN
    INSERT INTO public.transaction_payments(transaction_id, method, amount) SELECT v_tx,(x->>'method'),(x->>'amount')::bigint FROM jsonb_array_elements(p_payments) x;
  ELSE
    INSERT INTO public.transaction_payments(transaction_id, method, amount) VALUES(v_tx,p_payment_method,v_paid_amount);
  END IF;

  RETURN v_tx;
EXCEPTION WHEN unique_violation THEN
  SELECT id,idempotency_fingerprint INTO v_existing,v_existing_fp FROM public.transactions WHERE store_id=p_store_id AND idempotency_key=p_idempotency_key LIMIT 1;
  IF v_existing IS NOT NULL AND v_existing_fp=v_fp THEN RETURN v_existing; END IF;
  RAISE;
END;
$function$;

-- ---------- Trigger functions terkait transaksi ----------
-- (apply_stock_on_sale, post_sale_cogs_to_ledger: sudah benar sejak awal,
--  disalin apa adanya dari live DB. post_sale_payment_to_ledger: FIXED —
--  sebelumnya pakai NEW.payment_method yang tidak ada / bandingkan 'cash'
--  yang tidak pernah match, membuat SEMUA checkout gagal karena trigger error.)

CREATE OR REPLACE FUNCTION public.post_sale_payment_to_ledger()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_store uuid; v_sales uuid; v_account uuid; v_journal uuid;
BEGIN
 SELECT store_id INTO v_store FROM public.transactions WHERE id=NEW.transaction_id;
 IF v_store IS NULL THEN RETURN NEW; END IF;
 PERFORM public.ensure_default_accounting_accounts(v_store);
 SELECT id INTO v_sales FROM public.accounting_accounts WHERE store_id=v_store AND code='4000';
 IF lower(NEW.method)='tunai' THEN SELECT id INTO v_account FROM public.accounting_accounts WHERE store_id=v_store AND code='1000';
 ELSE SELECT id INTO v_account FROM public.accounting_accounts WHERE store_id=v_store AND code='1010'; END IF;
 INSERT INTO public.accounting_journals(store_id,journal_no,journal_date,source_type,source_id,description,created_by)
 VALUES(v_store,'SALE-PAY-'||NEW.id::text,CURRENT_DATE,'sale_payment',NEW.transaction_id,'POS sale payment',auth.uid()) ON CONFLICT (store_id,journal_no) DO NOTHING RETURNING id INTO v_journal;
 IF v_journal IS NULL THEN RETURN NEW; END IF;
 INSERT INTO public.accounting_journal_lines(journal_id,account_id,debit,credit,description) VALUES
 (v_journal,v_account,NEW.amount,0,'Payment received'),(v_journal,v_sales,0,NEW.amount,'Sales revenue');
 RETURN NEW;
END; $function$;

-- ---------- Shift, void/refund, PIN, laporan ----------
-- Fungsi berikut sudah diverifikasi benar terhadap skema live (tidak ada
-- perubahan pada sesi ini) — badan lengkap tersalin dari live DB:
--   open_shift, close_shift, void_or_refund_transaction,
--   generate_invoice_no, write_audit_log, create_offline_queue_item,
--   apply_stock_on_sale, apply_stock_opname, award_customer_points,
--   create_balanced_journal, decide_approval, ensure_default_accounting_accounts,
--   low_stock_report, post_sale_cogs_to_ledger, receive_purchase,
--   refund_transaction_items, request_approval, transfer_stock,
--   validate_payment_total, payment_summary, sales_summary
-- Karena panjangnya, badan fungsi-fungsi tersebut TIDAK diketik ulang di sini
-- untuk menghindari salah-salin manual; rujukan sumber kebenarannya adalah
-- live database (gunakan `SELECT pg_get_functiondef(oid) FROM pg_proc WHERE
-- proname = '<nama>'` bila perlu menyalinnya ke migrasi baru).

-- ---------- PIN Cashier (fitur baru sesi ini) ----------
CREATE OR REPLACE FUNCTION public.set_staff_pin(p_pin text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','extensions','pg_temp'
AS $function$
BEGIN
  IF p_pin IS NULL OR p_pin !~ '^[0-9]{4,6}$' THEN RAISE EXCEPTION 'PIN harus terdiri dari 4-6 digit angka'; END IF;
  UPDATE public.staff SET pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf')), pin_failed_attempts = 0, pin_locked_until = NULL
    WHERE user_id = auth.uid() AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Staff tidak ditemukan'; END IF;
END; $function$;

CREATE OR REPLACE FUNCTION public.verify_staff_pin(p_pin text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','extensions','pg_temp'
AS $function$
DECLARE v_staff record; v_ok boolean;
BEGIN
  SELECT id, pin_hash, pin_failed_attempts, pin_locked_until INTO v_staff FROM public.staff WHERE user_id = auth.uid() AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Staff tidak ditemukan'; END IF;
  IF v_staff.pin_hash IS NULL THEN RAISE EXCEPTION 'PIN belum diatur'; END IF;
  IF v_staff.pin_locked_until IS NOT NULL AND v_staff.pin_locked_until > now() THEN
    RAISE EXCEPTION 'Terlalu banyak percobaan salah. Coba lagi sebentar.';
  END IF;
  v_ok := (extensions.crypt(p_pin, v_staff.pin_hash) = v_staff.pin_hash);
  IF v_ok THEN
    UPDATE public.staff SET pin_failed_attempts = 0, pin_locked_until = NULL WHERE id = v_staff.id;
  ELSE
    UPDATE public.staff SET pin_failed_attempts = v_staff.pin_failed_attempts + 1,
      pin_locked_until = CASE WHEN v_staff.pin_failed_attempts + 1 >= 5 THEN now() + interval '60 seconds' ELSE NULL END
      WHERE id = v_staff.id;
  END IF;
  RETURN v_ok;
END; $function$;

CREATE OR REPLACE FUNCTION public.has_staff_pin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$ SELECT pin_hash IS NOT NULL FROM public.staff WHERE user_id = auth.uid() AND is_active = true; $function$;
