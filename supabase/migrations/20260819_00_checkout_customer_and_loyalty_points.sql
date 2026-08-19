-- ============================================================================
-- FEAT: checkout_transaction dukung customer_id + loyalty points otomatis
-- ============================================================================
-- Ditambahkan untuk fitur Customer/Member. checkout_transaction sekarang
-- menerima parameter baru p_customer_id (opsional):
--   - divalidasi milik toko yang sama sebelum dipakai
--   - disimpan ke transactions.customer_id
--   - kalau ada, otomatis kasih 1 poin loyalty per kelipatan Rp 10.000 dari
--     total transaksi, dicatat ke customer_point_ledger sebagai jejak audit
--
-- PENTING: karena ini menambah parameter baru, CREATE OR REPLACE FUNCTION
-- membuat OVERLOAD BARU alih-alih mengganti versi lama (beda tanda tangan
-- parameter) — pola yang sudah dua kali terjadi sebelumnya di sesi ini.
-- Versi lama (8 parameter, tanpa p_customer_id) SUDAH DIHAPUS lewat:
--   DROP FUNCTION IF EXISTS public.checkout_transaction(uuid, uuid, jsonb,
--     bigint, text, jsonb, text, bigint);
-- Badan fungsi final (9 parameter) ada di bawah ini.

CREATE OR REPLACE FUNCTION public.checkout_transaction(
  p_store_id uuid, p_shift_id uuid, p_items jsonb, p_paid_amount bigint,
  p_payment_method text, p_payments jsonb DEFAULT NULL::jsonb,
  p_idempotency_key text DEFAULT NULL::text, p_transaction_discount bigint DEFAULT 0,
  p_customer_id uuid DEFAULT NULL::uuid
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_existing uuid; v_existing_fp text; v_tx uuid;
  v_subtotal bigint; v_line_discount bigint; v_discount bigint; v_total bigint;
  v_item jsonb; v_product record; v_qty integer; v_item_discount bigint; v_gross bigint;
  v_fp text; v_staff_id uuid;
  v_paid_amount bigint; v_effective_method text; v_distinct_methods integer; v_payment_count integer;
  v_points_earned bigint;
BEGIN
  IF NOT public.user_store_access(p_store_id) THEN RAISE EXCEPTION 'Unauthorized store'; END IF;
  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) < 16 OR length(p_idempotency_key) > 128 THEN RAISE EXCEPTION 'Invalid idempotency key'; END IF;

  SELECT id INTO v_staff_id FROM public.staff WHERE user_id = auth.uid() AND store_id = p_store_id AND is_active = true;
  IF v_staff_id IS NULL THEN RAISE EXCEPTION 'Staff tidak ditemukan atau tidak aktif'; END IF;

  IF p_customer_id IS NOT NULL THEN
    PERFORM 1 FROM public.customers WHERE id = p_customer_id AND store_id = p_store_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Pelanggan tidak ditemukan untuk toko ini'; END IF;
  END IF;

  v_fp := encode(digest(jsonb_build_object('store_id',p_store_id,'shift_id',p_shift_id,'items',p_items,'paid_amount',p_paid_amount,'payment_method',p_payment_method,'payments',p_payments,'transaction_discount',p_transaction_discount,'customer_id',p_customer_id)::text,'sha256'),'hex');

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
    IF jsonb_typeof(p_payments) <> 'array' OR jsonb_array_length(p_payments) = 0 THEN
      RAISE EXCEPTION 'Invalid payments';
    END IF;
    SELECT COALESCE(SUM((x->>'amount')::bigint), 0), COUNT(DISTINCT (x->>'method')), COUNT(*)
      INTO v_paid_amount, v_distinct_methods, v_payment_count
      FROM jsonb_array_elements(p_payments) x;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_payments) x WHERE (x->>'amount')::bigint <= 0) THEN
      RAISE EXCEPTION 'Setiap nominal pembayaran harus lebih dari 0';
    END IF;
    v_effective_method := CASE WHEN v_distinct_methods > 1 OR v_payment_count > 1 THEN 'campuran'
                               ELSE (SELECT (x->>'method') FROM jsonb_array_elements(p_payments) x LIMIT 1) END;
  ELSE
    v_paid_amount := p_paid_amount;
    v_effective_method := p_payment_method;
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
    v_subtotal := v_subtotal + v_gross;
    v_line_discount := v_line_discount + v_item_discount;
  END LOOP;

  v_discount := LEAST(v_line_discount + GREATEST(COALESCE(p_transaction_discount,0),0), v_subtotal);
  v_total := v_subtotal - v_discount;
  IF v_paid_amount < v_total THEN RAISE EXCEPTION 'Insufficient payment'; END IF;

  INSERT INTO public.transactions(
    store_id, shift_id, staff_id, subtotal, discount, total, paid_amount, change_amount,
    payment_method, status, idempotency_key, idempotency_fingerprint, customer_id
  ) VALUES (
    p_store_id, p_shift_id, v_staff_id, v_subtotal, v_discount, v_total, v_paid_amount, v_paid_amount - v_total,
    v_effective_method::payment_method, 'completed', p_idempotency_key, v_fp, p_customer_id
  ) RETURNING id INTO v_tx;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::integer;
    SELECT id,name,selling_price,cost_price,stock INTO v_product FROM public.products WHERE id=(v_item->>'product_id')::uuid AND store_id=p_store_id FOR UPDATE;
    v_gross := v_product.selling_price::bigint * v_qty;
    v_item_discount := LEAST(GREATEST(COALESCE((v_item->>'discount')::bigint,0), 0), v_gross);

    INSERT INTO public.transaction_items(transaction_id, product_id, product_name, price, cost_price, quantity, subtotal, discount)
    VALUES (v_tx, v_product.id, v_product.name, v_product.selling_price, v_product.cost_price, v_qty, v_gross - v_item_discount, v_item_discount);
  END LOOP;

  IF p_payments IS NOT NULL THEN
    INSERT INTO public.transaction_payments(transaction_id, method, amount) SELECT v_tx,(x->>'method'),(x->>'amount')::bigint FROM jsonb_array_elements(p_payments) x;
  ELSE
    INSERT INTO public.transaction_payments(transaction_id, method, amount) VALUES(v_tx,p_payment_method,v_paid_amount);
  END IF;

  IF p_customer_id IS NOT NULL THEN
    v_points_earned := floor(v_total / 10000);
    IF v_points_earned > 0 THEN
      UPDATE public.customers SET points = points + v_points_earned, updated_at = now() WHERE id = p_customer_id;
      INSERT INTO public.customer_point_ledger(store_id, customer_id, transaction_id, points_delta, reason)
      VALUES (p_store_id, p_customer_id, v_tx, v_points_earned, 'Poin dari pembelian');
    END IF;
  END IF;

  RETURN v_tx;
EXCEPTION WHEN unique_violation THEN
  SELECT id,idempotency_fingerprint INTO v_existing,v_existing_fp FROM public.transactions WHERE store_id=p_store_id AND idempotency_key=p_idempotency_key LIMIT 1;
  IF v_existing IS NOT NULL AND v_existing_fp=v_fp THEN RETURN v_existing; END IF;
  RAISE;
END;
$function$;

DROP FUNCTION IF EXISTS public.checkout_transaction(uuid, uuid, jsonb, bigint, text, jsonb, text, bigint);
