-- ============================================================================
-- Fitur PPOB/Pulsa (H2H.id reseller) -- terpisah TOTAL dari alur POS inti
-- (products/transactions/dst). Model: saldo prepaid per toko, katalog +
-- margin diatur terpusat (platform owner), toko top up dulu baru bisa jual.
--
-- CATATAN: migration ini sudah diterapkan live ke project (24 Agu 2026)
-- lewat Supabase MCP saat development. File ini cuma buat catatan riwayat
-- di repo git -- kalau nanti setup project baru dari nol, jalankan file
-- ini seperti migration biasa.
-- ============================================================================

-- Platform admin (pemilik Kasir Pro) -- dipakai buat approve top-up saldo
-- toko. Tabel ini SENGAJA tanpa policy insert/update untuk authenticated;
-- baris pertama harus diisi manual lewat Supabase Studio oleh pemilik.
CREATE TABLE public.platform_admins (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_platform_admin()
 RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.platform_admins WHERE user_id = auth.uid());
$function$;

-- Saldo prepaid H2H per toko
CREATE TABLE public.store_ppob_wallets (
  store_id uuid PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
  balance bigint NOT NULL DEFAULT 0 CHECK (balance >= 0),
  version integer NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.store_ppob_wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY store_ppob_wallets_select ON public.store_ppob_wallets
  FOR SELECT USING (public.user_store_access(store_id) OR public.is_platform_admin());
-- Tidak ada policy insert/update/delete untuk authenticated -- saldo cuma
-- boleh berubah lewat RPC SECURITY DEFINER di bawah (reserve/finalize/topup).

-- Permintaan top-up saldo per toko
CREATE TABLE public.store_ppob_deposits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES public.staff(id),
  amount bigint NOT NULL CHECK (amount > 0),
  proof_url text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes text,
  processed_by uuid REFERENCES auth.users(id),
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.store_ppob_deposits ENABLE ROW LEVEL SECURITY;
CREATE POLICY store_ppob_deposits_select ON public.store_ppob_deposits
  FOR SELECT USING (public.user_store_access(store_id) OR public.is_platform_admin());
CREATE POLICY store_ppob_deposits_insert ON public.store_ppob_deposits
  FOR INSERT WITH CHECK (public.is_store_admin(store_id) AND requested_by IN (
    SELECT id FROM public.staff WHERE store_id = store_ppob_deposits.store_id AND user_id = auth.uid()
  ));
-- approve/reject cuma lewat RPC (decide_ppob_deposit) -- update langsung
-- oleh authenticated tidak diizinkan (tidak ada policy UPDATE).

-- Katalog produk H2H, platform-wide (bukan per-toko) -- harga & margin
-- diatur terpusat oleh platform admin.
CREATE TABLE public.ppob_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  h2h_product_code text NOT NULL UNIQUE,
  category text NOT NULL,
  operator text,
  name text NOT NULL,
  base_price bigint NOT NULL,
  margin_percent numeric(6,2) NOT NULL DEFAULT 0,
  sell_price bigint NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ppob_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY ppob_products_select ON public.ppob_products
  FOR SELECT USING ((SELECT auth.uid()) IS NOT NULL);
CREATE TRIGGER trg_touch_ppob_products BEFORE UPDATE ON public.ppob_products
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE INDEX idx_ppob_products_category ON public.ppob_products(category) WHERE is_active;

-- Order pulsa/PPOB per toko
CREATE TABLE public.ppob_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  staff_id uuid NOT NULL REFERENCES public.staff(id),
  product_id uuid NOT NULL REFERENCES public.ppob_products(id),
  customer_number text NOT NULL,
  base_price bigint NOT NULL,
  sell_price bigint NOT NULL,
  ref_id text NOT NULL UNIQUE,
  h2h_trx_id text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','success','failed')),
  sn text,
  failure_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.ppob_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY ppob_orders_select ON public.ppob_orders
  FOR SELECT USING (public.user_store_access(store_id) OR public.is_platform_admin());
CREATE TRIGGER trg_touch_ppob_orders BEFORE UPDATE ON public.ppob_orders
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE INDEX idx_ppob_orders_store ON public.ppob_orders(store_id, created_at DESC);

-- Auto-create baris wallet PPOB (saldo 0) tiap kali toko baru dibuat.
CREATE OR REPLACE FUNCTION public.create_store_ppob_wallet()
 RETURNS trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
BEGIN
  INSERT INTO public.store_ppob_wallets(store_id, balance) VALUES (NEW.id, 0)
  ON CONFLICT (store_id) DO NOTHING;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_create_store_ppob_wallet AFTER INSERT ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.create_store_ppob_wallet();

INSERT INTO public.store_ppob_wallets(store_id, balance)
SELECT id, 0 FROM public.stores
ON CONFLICT (store_id) DO NOTHING;

-- ============================================================================
-- reserve_ppob_order: dipanggil Edge Function SEBELUM order dikirim ke H2H.
-- Lock wallet toko (FOR UPDATE), validasi staff aktif & produk aktif,
-- potong saldo di muka, insert order status='pending'. Kalau H2H gagal
-- nanti, finalize_ppob_order yang refund. Pola sama persis dengan
-- reserve_ppob_order di backend NexaPay (row-locked, anti race condition).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reserve_ppob_order(
  p_store_id uuid,
  p_staff_id uuid,
  p_product_id uuid,
  p_customer_number text,
  p_ref_id text
)
RETURNS TABLE(result text, order_id uuid, sell_price bigint, h2h_product_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
declare
  v_staff_ok boolean;
  v_wallet public.store_ppob_wallets%rowtype;
  v_product public.ppob_products%rowtype;
  v_order_id uuid;
begin
  select exists(
    select 1 from public.staff
    where id = p_staff_id and store_id = p_store_id and is_active = true and user_id = auth.uid()
  ) into v_staff_ok;
  if not v_staff_ok then
    return query select 'unauthorized', null::uuid, null::bigint, null::text;
    return;
  end if;

  select * into v_product from public.ppob_products where id = p_product_id for update;
  if not found or v_product.is_active = false then
    return query select 'product_unavailable', null::uuid, null::bigint, null::text;
    return;
  end if;

  select * into v_wallet from public.store_ppob_wallets where store_id = p_store_id for update;
  if not found then
    return query select 'wallet_not_found', null::uuid, null::bigint, null::text;
    return;
  end if;

  if v_wallet.balance < v_product.sell_price then
    return query select 'insufficient_balance', null::uuid, v_product.sell_price, v_product.h2h_product_code;
    return;
  end if;

  update public.store_ppob_wallets
    set balance = balance - v_product.sell_price, version = version + 1, updated_at = now()
    where store_id = p_store_id;

  insert into public.ppob_orders(store_id, staff_id, product_id, customer_number, base_price, sell_price, ref_id, status)
  values (p_store_id, p_staff_id, p_product_id, p_customer_number, v_product.base_price, v_product.sell_price, p_ref_id, 'pending')
  returning id into v_order_id;

  return query select 'reserved', v_order_id, v_product.sell_price, v_product.h2h_product_code;
end;
$function$;

-- ============================================================================
-- finalize_ppob_order: dipanggil Edge Function SETELAH dapat respons final
-- dari H2H. Idempotent -- order yang udah gak 'pending' diabaikan.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.finalize_ppob_order(
  p_ref_id text,
  p_status text,
  p_h2h_trx_id text,
  p_sn text,
  p_failure_reason text
)
RETURNS TABLE(result text, order_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
declare
  v_order public.ppob_orders%rowtype;
begin
  if p_status not in ('success','failed') then
    raise exception 'p_status harus success atau failed';
  end if;

  select * into v_order from public.ppob_orders where ref_id = p_ref_id for update;
  if not found then
    return query select 'not_found', null::uuid;
    return;
  end if;
  if v_order.status <> 'pending' then
    return query select 'already_finalized', v_order.id;
    return;
  end if;

  update public.ppob_orders
    set status = p_status, h2h_trx_id = p_h2h_trx_id, sn = p_sn, failure_reason = p_failure_reason
    where id = v_order.id and status = 'pending';

  if p_status = 'failed' then
    update public.store_ppob_wallets
      set balance = balance + v_order.sell_price, version = version + 1, updated_at = now()
      where store_id = v_order.store_id;
  end if;

  return query select 'finalized', v_order.id;
end;
$function$;

-- ============================================================================
-- decide_ppob_deposit: approve/reject top-up saldo toko. Cuma platform admin.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.decide_ppob_deposit(
  p_deposit_id uuid,
  p_approve boolean,
  p_notes text
)
RETURNS TABLE(result text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
declare
  v_dep public.store_ppob_deposits%rowtype;
begin
  if not public.is_platform_admin() then
    return query select 'unauthorized';
    return;
  end if;

  select * into v_dep from public.store_ppob_deposits where id = p_deposit_id for update;
  if not found then
    return query select 'not_found';
    return;
  end if;
  if v_dep.status <> 'pending' then
    return query select 'already_processed';
    return;
  end if;

  update public.store_ppob_deposits
    set status = case when p_approve then 'approved' else 'rejected' end,
        notes = p_notes, processed_by = auth.uid(), processed_at = now()
    where id = v_dep.id and status = 'pending';

  if p_approve then
    update public.store_ppob_wallets
      set balance = balance + v_dep.amount, version = version + 1, updated_at = now()
      where store_id = v_dep.store_id;
  end if;

  return query select 'done';
end;
$function$;
