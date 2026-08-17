-- ============================================================================
-- BASELINE SCHEMA SNAPSHOT — Kasir Pro (project gyibrbxvffqfxveckhcp)
-- ============================================================================
-- Direkonstruksi dari state live database pada 2026-08-17. Sebelum file ini
-- dibuat, 45 migrasi sudah diterapkan langsung ke production lewat Supabase
-- MCP tool TANPA pernah disimpan sebagai file di repo — jadi tidak ada
-- riwayat git untuk skema sebelum tanggal ini. File ini adalah upaya
-- menangkap state tersebut secara utuh, disusun ulang dalam urutan yang bisa
-- dijalankan dari kosong (extensions -> enum -> sequence -> tabel -> index ->
-- fungsi -> trigger -> RLS).
--
-- Ke depan: setiap migrasi baru WAJIB juga disimpan sebagai file terpisah di
-- folder ini (bukan cuma diterapkan ke production), supaya tidak terulang.
-- ============================================================================

-- ---------- ENUM TYPES ----------
CREATE TYPE public.payment_method AS ENUM ('tunai','qris','transfer','kartu','lainnya','campuran');
CREATE TYPE public.staff_role AS ENUM ('owner','admin','kasir');
CREATE TYPE public.stock_movement_type AS ENUM ('sale','restock','adjustment','return');
CREATE TYPE public.transaction_status AS ENUM ('completed','void','refunded');

-- ---------- SEQUENCES ----------
CREATE SEQUENCE public.invoice_seq START 1 INCREMENT 1;
CREATE SEQUENCE public.purchase_no_seq START 1 INCREMENT 1;

-- ---------- TABLES (urutan mengikuti dependency FK) ----------

CREATE TABLE public.stores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  name text NOT NULL,
  address text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT stores_pkey PRIMARY KEY (id),
  CONSTRAINT stores_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.staff (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role staff_role NOT NULL DEFAULT 'kasir'::staff_role,
  full_name text NOT NULL,
  pin_hash text,
  is_active boolean NOT NULL DEFAULT true,
  shift_open_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  pin_failed_attempts integer NOT NULL DEFAULT 0,
  pin_locked_until timestamp with time zone,
  CONSTRAINT staff_pkey PRIMARY KEY (id),
  CONSTRAINT staff_store_id_user_id_key UNIQUE (store_id, user_id),
  CONSTRAINT staff_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT staff_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (id),
  CONSTRAINT categories_store_id_name_key UNIQUE (store_id, name),
  CONSTRAINT categories_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  category_id uuid,
  name text NOT NULL,
  sku text,
  photo_url text,
  selling_price bigint NOT NULL DEFAULT 0,
  cost_price bigint NOT NULL DEFAULT 0,
  stock integer,
  low_stock_threshold integer NOT NULL DEFAULT 5,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
  CONSTRAINT products_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  name text NOT NULL,
  phone text,
  email text,
  member_code text,
  points bigint NOT NULL DEFAULT 0,
  tier text NOT NULL DEFAULT 'regular'::text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customers_pkey PRIMARY KEY (id),
  CONSTRAINT customers_store_id_member_code_key UNIQUE (store_id, member_code),
  CONSTRAINT customers_points_check CHECK ((points >= 0)),
  CONSTRAINT customers_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.suppliers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  name text NOT NULL,
  phone text,
  address text,
  note text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT suppliers_pkey PRIMARY KEY (id),
  CONSTRAINT suppliers_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE public.warehouses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  name text NOT NULL,
  address text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT warehouses_pkey PRIMARY KEY (id),
  CONSTRAINT warehouses_store_id_name_key UNIQUE (store_id, name),
  CONSTRAINT warehouses_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.devices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  staff_id uuid,
  device_key text NOT NULL,
  device_name text NOT NULL,
  platform text,
  app_version text,
  last_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  revoked_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT devices_pkey PRIMARY KEY (id),
  CONSTRAINT devices_store_id_device_key_key UNIQUE (store_id, device_key),
  CONSTRAINT devices_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT devices_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE SET NULL
);

CREATE TABLE public.promotions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  name text NOT NULL,
  promotion_type text NOT NULL,
  value bigint NOT NULL DEFAULT 0,
  minimum_purchase bigint NOT NULL DEFAULT 0,
  maximum_discount bigint,
  usage_limit bigint,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT promotions_pkey PRIMARY KEY (id),
  CONSTRAINT promotions_check CHECK ((ends_at > starts_at)),
  CONSTRAINT promotions_promotion_type_check CHECK ((promotion_type = ANY (ARRAY['percentage'::text,'fixed'::text,'buy_x_get_y'::text,'bundle'::text,'voucher'::text]))),
  CONSTRAINT promotions_value_check CHECK ((value >= 0)),
  CONSTRAINT promotions_minimum_purchase_check CHECK ((minimum_purchase >= 0)),
  CONSTRAINT promotions_maximum_discount_check CHECK (((maximum_discount IS NULL) OR (maximum_discount >= 0))),
  CONSTRAINT promotions_usage_limit_check CHECK (((usage_limit IS NULL) OR (usage_limit > 0))),
  CONSTRAINT promotions_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT promotions_created_by_fkey FOREIGN KEY (created_by) REFERENCES staff(id) ON DELETE SET NULL
);

CREATE TABLE public.shifts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  opening_cash bigint NOT NULL DEFAULT 0,
  closing_cash bigint,
  expected_cash bigint,
  cash_difference bigint,
  opened_at timestamp with time zone NOT NULL DEFAULT now(),
  closed_at timestamp with time zone,
  CONSTRAINT shifts_pkey PRIMARY KEY (id),
  CONSTRAINT shifts_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT shifts_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id)
);
CREATE UNIQUE INDEX uq_shifts_one_open_per_staff ON public.shifts USING btree (staff_id) WHERE (closed_at IS NULL);

CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  staff_id uuid,
  invoice_no text NOT NULL,
  subtotal bigint NOT NULL,
  discount bigint NOT NULL DEFAULT 0,
  tax bigint NOT NULL DEFAULT 0,
  total bigint NOT NULL,
  paid_amount bigint NOT NULL,
  change_amount bigint NOT NULL DEFAULT 0,
  payment_method payment_method NOT NULL DEFAULT 'tunai'::payment_method,
  status transaction_status NOT NULL DEFAULT 'completed'::transaction_status,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  shift_id uuid,
  customer_id uuid,
  idempotency_key text,
  idempotency_fingerprint text,
  CONSTRAINT transactions_pkey PRIMARY KEY (id),
  CONSTRAINT transactions_store_id_invoice_no_key UNIQUE (store_id, invoice_no),
  CONSTRAINT chk_paid_amount_gte_total CHECK ((paid_amount >= total)),
  CONSTRAINT transactions_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL,
  CONSTRAINT transactions_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES shifts(id),
  CONSTRAINT transactions_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id)
);
CREATE UNIQUE INDEX ux_transactions_store_idempotency_key ON public.transactions USING btree (store_id, idempotency_key) WHERE (idempotency_key IS NOT NULL);

CREATE TABLE public.transaction_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  product_id uuid,
  product_name text NOT NULL,
  price bigint NOT NULL,
  cost_price bigint NOT NULL DEFAULT 0,
  quantity integer NOT NULL,
  subtotal bigint NOT NULL,
  discount bigint NOT NULL DEFAULT 0,
  CONSTRAINT transaction_items_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_items_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT transaction_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
);

CREATE TABLE public.transaction_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  method text NOT NULL,
  amount bigint NOT NULL,
  reference_no text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  provider text,
  status text NOT NULL DEFAULT 'paid'::text,
  paid_at timestamp with time zone,
  CONSTRAINT transaction_payments_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_payments_status_check CHECK ((status = ANY (ARRAY['pending'::text,'paid'::text,'failed'::text,'refunded'::text]))),
  CONSTRAINT transaction_payments_method_check CHECK ((method = ANY (ARRAY['tunai'::text,'qris'::text,'transfer'::text,'kartu'::text,'lainnya'::text]))),
  CONSTRAINT transaction_payments_amount_check CHECK ((amount > 0)),
  CONSTRAINT transaction_payments_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
);

CREATE TABLE public.stock_movements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  product_id uuid NOT NULL,
  type stock_movement_type NOT NULL,
  quantity_change integer NOT NULL,
  stock_after integer,
  note text,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT stock_movements_pkey PRIMARY KEY (id),
  CONSTRAINT stock_movements_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT stock_movements_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT stock_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES staff(id)
);

CREATE TABLE public.cash_movements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  shift_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  type text NOT NULL,
  amount bigint NOT NULL,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT cash_movements_pkey PRIMARY KEY (id),
  CONSTRAINT cash_movements_type_check CHECK ((type = ANY (ARRAY['cash_in'::text,'cash_out'::text,'expense'::text]))),
  CONSTRAINT cash_movements_amount_check CHECK ((amount > 0)),
  CONSTRAINT cash_movements_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id),
  CONSTRAINT cash_movements_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id),
  CONSTRAINT cash_movements_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES shifts(id)
);

CREATE TABLE public.expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  shift_id uuid,
  staff_id uuid NOT NULL,
  category text NOT NULL,
  amount bigint NOT NULL,
  note text,
  expense_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT expenses_pkey PRIMARY KEY (id),
  CONSTRAINT expenses_amount_check CHECK ((amount > 0)),
  CONSTRAINT expenses_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id),
  CONSTRAINT expenses_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT expenses_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL
);

CREATE TABLE public.refunds (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL,
  store_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  total_amount bigint NOT NULL,
  reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT refunds_pkey PRIMARY KEY (id),
  CONSTRAINT refunds_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(id),
  CONSTRAINT refunds_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id),
  CONSTRAINT refunds_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE public.refund_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  refund_id uuid NOT NULL,
  transaction_item_id uuid NOT NULL,
  quantity integer NOT NULL,
  amount bigint NOT NULL,
  CONSTRAINT refund_items_pkey PRIMARY KEY (id),
  CONSTRAINT refund_items_quantity_check CHECK ((quantity > 0)),
  CONSTRAINT refund_items_transaction_item_id_fkey FOREIGN KEY (transaction_item_id) REFERENCES transaction_items(id),
  CONSTRAINT refund_items_refund_id_fkey FOREIGN KEY (refund_id) REFERENCES refunds(id) ON DELETE CASCADE
);

CREATE TABLE public.purchases (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  supplier_id uuid,
  staff_id uuid NOT NULL,
  purchase_no text NOT NULL,
  total_cost bigint NOT NULL DEFAULT 0,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT purchases_pkey PRIMARY KEY (id),
  CONSTRAINT purchases_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id),
  CONSTRAINT purchases_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id),
  CONSTRAINT purchases_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

CREATE TABLE public.purchase_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  purchase_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL,
  cost_price bigint NOT NULL,
  subtotal bigint NOT NULL,
  CONSTRAINT purchase_items_pkey PRIMARY KEY (id),
  CONSTRAINT purchase_items_quantity_check CHECK ((quantity > 0)),
  CONSTRAINT purchase_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT purchase_items_purchase_id_fkey FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
);

CREATE TABLE public.stock_opnames (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT stock_opnames_pkey PRIMARY KEY (id),
  CONSTRAINT stock_opnames_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id),
  CONSTRAINT stock_opnames_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE public.stock_opname_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  stock_opname_id uuid NOT NULL,
  product_id uuid NOT NULL,
  system_stock integer NOT NULL,
  counted_stock integer NOT NULL,
  difference integer NOT NULL,
  CONSTRAINT stock_opname_items_pkey PRIMARY KEY (id),
  CONSTRAINT stock_opname_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT stock_opname_items_stock_opname_id_fkey FOREIGN KEY (stock_opname_id) REFERENCES stock_opnames(id) ON DELETE CASCADE
);

CREATE TABLE public.stock_transfers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  from_warehouse_id uuid NOT NULL,
  to_warehouse_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'completed'::text,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT stock_transfers_pkey PRIMARY KEY (id),
  CONSTRAINT stock_transfers_status_check CHECK ((status = ANY (ARRAY['draft'::text,'completed'::text,'cancelled'::text]))),
  CONSTRAINT stock_transfers_check CHECK ((from_warehouse_id <> to_warehouse_id)),
  CONSTRAINT stock_transfers_to_warehouse_id_fkey FOREIGN KEY (to_warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT stock_transfers_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT stock_transfers_from_warehouse_id_fkey FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(id),
  CONSTRAINT stock_transfers_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id)
);

CREATE TABLE public.stock_transfer_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  transfer_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL,
  CONSTRAINT stock_transfer_items_pkey PRIMARY KEY (id),
  CONSTRAINT stock_transfer_items_quantity_check CHECK ((quantity > 0)),
  CONSTRAINT stock_transfer_items_transfer_id_fkey FOREIGN KEY (transfer_id) REFERENCES stock_transfers(id) ON DELETE CASCADE,
  CONSTRAINT stock_transfer_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE public.warehouse_stock (
  warehouse_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT warehouse_stock_pkey PRIMARY KEY (warehouse_id, product_id),
  CONSTRAINT warehouse_stock_quantity_check CHECK ((quantity >= 0)),
  CONSTRAINT warehouse_stock_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
  CONSTRAINT warehouse_stock_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE TABLE public.customer_point_ledger (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  transaction_id uuid,
  points_delta bigint NOT NULL,
  reason text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customer_point_ledger_pkey PRIMARY KEY (id),
  CONSTRAINT customer_point_ledger_points_delta_check CHECK ((points_delta <> 0)),
  CONSTRAINT customer_point_ledger_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
  CONSTRAINT customer_point_ledger_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT customer_point_ledger_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
);

CREATE TABLE public.promotion_products (
  promotion_id uuid NOT NULL,
  product_id uuid NOT NULL,
  CONSTRAINT promotion_products_pkey PRIMARY KEY (promotion_id, product_id),
  CONSTRAINT promotion_products_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE CASCADE,
  CONSTRAINT promotion_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE TABLE public.promotion_categories (
  promotion_id uuid NOT NULL,
  category_id uuid NOT NULL,
  CONSTRAINT promotion_categories_pkey PRIMARY KEY (promotion_id, category_id),
  CONSTRAINT promotion_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
  CONSTRAINT promotion_categories_promotion_id_fkey FOREIGN KEY (promotion_id) REFERENCES promotions(id) ON DELETE CASCADE
);

CREATE TABLE public.approval_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  requested_by uuid NOT NULL,
  approved_by uuid,
  request_type text NOT NULL,
  record_id uuid,
  amount bigint,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text,
  decision_note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  decided_at timestamp with time zone,
  CONSTRAINT approval_requests_pkey PRIMARY KEY (id),
  CONSTRAINT approval_requests_request_type_check CHECK ((request_type = ANY (ARRAY['void'::text,'refund'::text,'discount'::text,'stock_adjustment'::text,'cash_out'::text,'price_change'::text]))),
  CONSTRAINT approval_requests_amount_check CHECK (((amount IS NULL) OR (amount >= 0))),
  CONSTRAINT approval_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text,'approved'::text,'rejected'::text,'cancelled'::text]))),
  CONSTRAINT approval_requests_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT approval_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES staff(id) ON DELETE RESTRICT,
  CONSTRAINT approval_requests_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES staff(id) ON DELETE SET NULL
);

CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  actor_user_id uuid,
  actor_staff_id uuid,
  table_name text NOT NULL,
  record_id uuid NOT NULL,
  action text NOT NULL,
  old_data jsonb,
  new_data jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT audit_logs_actor_staff_id_fkey FOREIGN KEY (actor_staff_id) REFERENCES staff(id),
  CONSTRAINT audit_logs_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id)
);

CREATE TABLE public.held_carts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  shift_id uuid,
  staff_id uuid NOT NULL,
  label text,
  items jsonb NOT NULL,
  transaction_discount bigint NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT held_carts_pkey PRIMARY KEY (id),
  CONSTRAINT held_carts_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE CASCADE,
  CONSTRAINT held_carts_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT held_carts_shift_id_fkey FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL
);

CREATE TABLE public.offline_sync_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  device_id uuid NOT NULL,
  operation_key text NOT NULL,
  operation_type text NOT NULL,
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text,
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  processed_at timestamp with time zone,
  CONSTRAINT offline_sync_queue_pkey PRIMARY KEY (id),
  CONSTRAINT offline_sync_queue_device_id_operation_key_key UNIQUE (device_id, operation_key),
  CONSTRAINT offline_sync_queue_operation_type_check CHECK ((operation_type = ANY (ARRAY['checkout'::text,'cash_movement'::text,'refund'::text,'stock_adjustment'::text]))),
  CONSTRAINT offline_sync_queue_status_check CHECK ((status = ANY (ARRAY['pending'::text,'processing'::text,'completed'::text,'failed'::text]))),
  CONSTRAINT offline_sync_queue_attempts_check CHECK ((attempts >= 0)),
  CONSTRAINT offline_sync_queue_device_id_fkey FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
  CONSTRAINT offline_sync_queue_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.accounting_accounts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  account_type text NOT NULL,
  parent_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT accounting_accounts_pkey PRIMARY KEY (id),
  CONSTRAINT accounting_accounts_store_id_code_key UNIQUE (store_id, code),
  CONSTRAINT accounting_accounts_account_type_check CHECK ((account_type = ANY (ARRAY['asset'::text,'liability'::text,'equity'::text,'revenue'::text,'expense'::text,'cogs'::text]))),
  CONSTRAINT accounting_accounts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES accounting_accounts(id) ON DELETE RESTRICT,
  CONSTRAINT accounting_accounts_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
);

CREATE TABLE public.accounting_journals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  journal_no text NOT NULL,
  journal_date date NOT NULL DEFAULT CURRENT_DATE,
  source_type text NOT NULL,
  source_id uuid,
  description text NOT NULL,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT accounting_journals_pkey PRIMARY KEY (id),
  CONSTRAINT accounting_journals_store_id_journal_no_key UNIQUE (store_id, journal_no),
  CONSTRAINT accounting_journals_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE,
  CONSTRAINT accounting_journals_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id)
);

CREATE TABLE public.accounting_journal_lines (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  journal_id uuid NOT NULL,
  account_id uuid NOT NULL,
  debit numeric(18,2) NOT NULL DEFAULT 0,
  credit numeric(18,2) NOT NULL DEFAULT 0,
  description text,
  CONSTRAINT accounting_journal_lines_pkey PRIMARY KEY (id),
  CONSTRAINT accounting_journal_lines_check CHECK ((((debit > (0)::numeric) AND (credit = (0)::numeric)) OR ((credit > (0)::numeric) AND (debit = (0)::numeric)))),
  CONSTRAINT accounting_journal_lines_debit_check CHECK ((debit >= (0)::numeric)),
  CONSTRAINT accounting_journal_lines_credit_check CHECK ((credit >= (0)::numeric)),
  CONSTRAINT accounting_journal_lines_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES accounting_journals(id) ON DELETE CASCADE,
  CONSTRAINT accounting_journal_lines_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounting_accounts(id) ON DELETE RESTRICT
);

-- ---------- INDEXES tambahan (non-constraint) ----------
CREATE INDEX idx_accounting_accounts_store ON public.accounting_accounts USING btree (store_id);
CREATE INDEX idx_accounting_journal_lines_account ON public.accounting_journal_lines USING btree (account_id);
CREATE INDEX idx_accounting_journal_lines_journal ON public.accounting_journal_lines USING btree (journal_id);
CREATE INDEX idx_accounting_journals_store_date ON public.accounting_journals USING btree (store_id, journal_date);
CREATE INDEX idx_approval_requests_approved_by ON public.approval_requests USING btree (approved_by);
CREATE INDEX idx_approval_requests_requested_by ON public.approval_requests USING btree (requested_by);
CREATE INDEX idx_approval_requests_store_status ON public.approval_requests USING btree (store_id, status, created_at DESC);
CREATE INDEX idx_audit_logs_actor_staff ON public.audit_logs USING btree (actor_staff_id);
CREATE INDEX idx_audit_logs_store_created ON public.audit_logs USING btree (store_id, created_at DESC);
CREATE INDEX idx_audit_logs_table_record ON public.audit_logs USING btree (table_name, record_id);
CREATE INDEX idx_cash_movements_shift ON public.cash_movements USING btree (shift_id);
CREATE INDEX idx_cash_movements_staff ON public.cash_movements USING btree (staff_id);
CREATE INDEX idx_cash_movements_store ON public.cash_movements USING btree (store_id);
CREATE INDEX idx_customer_point_ledger_customer_created ON public.customer_point_ledger USING btree (customer_id, created_at DESC);
CREATE INDEX idx_customer_point_ledger_store ON public.customer_point_ledger USING btree (store_id);
CREATE INDEX idx_customer_point_ledger_transaction ON public.customer_point_ledger USING btree (transaction_id);
CREATE INDEX idx_customers_store ON public.customers USING btree (store_id);
CREATE INDEX idx_customers_store_phone ON public.customers USING btree (store_id, phone);
CREATE INDEX idx_devices_staff ON public.devices USING btree (staff_id);
CREATE INDEX idx_devices_store ON public.devices USING btree (store_id);
CREATE INDEX idx_expenses_shift ON public.expenses USING btree (shift_id);
CREATE INDEX idx_expenses_staff ON public.expenses USING btree (staff_id);
CREATE INDEX idx_expenses_store_date ON public.expenses USING btree (store_id, expense_at DESC);
CREATE INDEX held_carts_store_idx ON public.held_carts USING btree (store_id, created_at DESC);
CREATE INDEX idx_offline_sync_queue_device_status ON public.offline_sync_queue USING btree (device_id, status, created_at);
CREATE INDEX idx_offline_sync_queue_store ON public.offline_sync_queue USING btree (store_id);
CREATE INDEX idx_products_category ON public.products USING btree (category_id);
CREATE INDEX idx_products_store ON public.products USING btree (store_id);
CREATE INDEX idx_promotion_categories_category ON public.promotion_categories USING btree (category_id);
CREATE INDEX idx_promotion_products_product ON public.promotion_products USING btree (product_id);
CREATE INDEX idx_promotions_created_by ON public.promotions USING btree (created_by);
CREATE INDEX idx_promotions_store_active_window ON public.promotions USING btree (store_id, is_active, starts_at, ends_at);
CREATE INDEX idx_purchase_items_product ON public.purchase_items USING btree (product_id);
CREATE INDEX idx_purchase_items_purchase ON public.purchase_items USING btree (purchase_id);
CREATE INDEX idx_purchases_staff ON public.purchases USING btree (staff_id);
CREATE INDEX idx_purchases_store ON public.purchases USING btree (store_id);
CREATE INDEX idx_purchases_supplier ON public.purchases USING btree (supplier_id);
CREATE INDEX idx_refund_items_refund ON public.refund_items USING btree (refund_id);
CREATE INDEX idx_refund_items_transaction_item ON public.refund_items USING btree (transaction_item_id);
CREATE INDEX idx_refunds_staff ON public.refunds USING btree (staff_id);
CREATE INDEX idx_refunds_store ON public.refunds USING btree (store_id);
CREATE INDEX idx_refunds_transaction ON public.refunds USING btree (transaction_id);
CREATE INDEX idx_shifts_store ON public.shifts USING btree (store_id);
CREATE INDEX idx_staff_user ON public.staff USING btree (user_id);
CREATE INDEX idx_stock_movements_created_by ON public.stock_movements USING btree (created_by);
CREATE INDEX idx_stock_movements_product ON public.stock_movements USING btree (product_id);
CREATE INDEX idx_stock_movements_store ON public.stock_movements USING btree (store_id);
CREATE INDEX idx_stock_opname_items_opname ON public.stock_opname_items USING btree (stock_opname_id);
CREATE INDEX idx_stock_opname_items_product ON public.stock_opname_items USING btree (product_id);
CREATE INDEX idx_stock_opnames_staff ON public.stock_opnames USING btree (staff_id);
CREATE INDEX idx_stock_opnames_store ON public.stock_opnames USING btree (store_id);
CREATE INDEX idx_stock_transfer_items_product ON public.stock_transfer_items USING btree (product_id);
CREATE INDEX idx_stock_transfer_items_transfer ON public.stock_transfer_items USING btree (transfer_id);
CREATE INDEX idx_stock_transfers_from ON public.stock_transfers USING btree (from_warehouse_id);
CREATE INDEX idx_stock_transfers_staff ON public.stock_transfers USING btree (staff_id);
CREATE INDEX idx_stock_transfers_store_created ON public.stock_transfers USING btree (store_id, created_at DESC);
CREATE INDEX idx_stock_transfers_to ON public.stock_transfers USING btree (to_warehouse_id);
CREATE INDEX idx_stores_owner ON public.stores USING btree (owner_id);
CREATE INDEX idx_suppliers_store ON public.suppliers USING btree (store_id);
CREATE INDEX idx_transaction_items_product ON public.transaction_items USING btree (product_id);
CREATE INDEX idx_transaction_items_tx ON public.transaction_items USING btree (transaction_id);
CREATE INDEX idx_transaction_payments_transaction ON public.transaction_payments USING btree (transaction_id);
CREATE INDEX idx_transactions_customer ON public.transactions USING btree (customer_id);
CREATE INDEX idx_transactions_shift ON public.transactions USING btree (shift_id);
CREATE INDEX idx_transactions_staff ON public.transactions USING btree (staff_id);
CREATE INDEX idx_transactions_store_date ON public.transactions USING btree (store_id, created_at DESC);
CREATE INDEX idx_warehouse_stock_product ON public.warehouse_stock USING btree (product_id);
CREATE INDEX idx_warehouses_store ON public.warehouses USING btree (store_id);

-- ---------- Aktifkan RLS untuk semua tabel ----------
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- NOTE: Definisi lengkap semua fungsi (checkout_transaction, RPC modul
-- purchasing/warehouse/accounting/dll), semua trigger, dan seluruh RLS
-- policy ada di file-file migrasi terpisah pada folder ini yang menyusul
-- setelah baseline ini (lihat urutan timestamp filename), karena volumenya
-- terlalu besar untuk satu file dan sebagian sudah diperbaiki ulang setelah
-- baseline ini direkonstruksi.
