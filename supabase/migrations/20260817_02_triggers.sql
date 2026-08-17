-- ============================================================================
-- TRIGGERS — snapshot dari live DB (2026-08-17)
-- ============================================================================
-- trg_apply_stock_on_sale dan trg_post_sale_cogs_ledger jalan otomatis
-- setiap ada baris baru di transaction_items (dipicu oleh checkout_transaction
-- RPC). trg_post_sale_payment_ledger jalan tiap baris baru di
-- transaction_payments. Fungsi post_sale_payment_to_ledger yang dipanggil
-- trigger terakhir ini SUDAH DIPERBAIKI (lihat 20260817_01_functions.sql) —
-- sebelumnya trigger ini bikin SEMUA checkout gagal karena error kolom.

CREATE TRIGGER audit_cash_movements AFTER INSERT OR DELETE OR UPDATE ON public.cash_movements FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION touch_customers_updated_at();
CREATE TRIGGER audit_products AFTER INSERT OR DELETE OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_products_touch BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
CREATE TRIGGER trg_promotions_updated_at BEFORE UPDATE ON public.promotions FOR EACH ROW EXECUTE FUNCTION touch_promotions_updated_at();
CREATE TRIGGER audit_purchases AFTER INSERT OR DELETE OR UPDATE ON public.purchases FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER audit_refunds AFTER INSERT OR DELETE OR UPDATE ON public.refunds FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER audit_shifts AFTER INSERT OR DELETE OR UPDATE ON public.shifts FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER audit_staff AFTER INSERT OR DELETE OR UPDATE ON public.staff FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER audit_stock_opnames AFTER INSERT OR DELETE OR UPDATE ON public.stock_opnames FOR EACH ROW EXECUTE FUNCTION write_audit_log();
-- Memotong stok + catat stock_movements otomatis saat item transaksi masuk.
-- checkout_transaction RPC SENGAJA tidak menduplikasi ini.
CREATE TRIGGER trg_apply_stock_on_sale AFTER INSERT ON public.transaction_items FOR EACH ROW EXECUTE FUNCTION apply_stock_on_sale();
CREATE TRIGGER trg_post_sale_cogs_ledger AFTER INSERT ON public.transaction_items FOR EACH ROW EXECUTE FUNCTION post_sale_cogs_to_ledger();
CREATE TRIGGER trg_post_sale_payment_ledger AFTER INSERT ON public.transaction_payments FOR EACH ROW EXECUTE FUNCTION post_sale_payment_to_ledger();
CREATE TRIGGER audit_transactions AFTER INSERT OR DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION write_audit_log();
CREATE TRIGGER trg_generate_invoice BEFORE INSERT ON public.transactions FOR EACH ROW EXECUTE FUNCTION generate_invoice_no();
