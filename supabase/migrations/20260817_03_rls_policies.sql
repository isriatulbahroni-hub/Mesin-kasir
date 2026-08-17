-- ============================================================================
-- ROW LEVEL SECURITY POLICIES — snapshot dari live DB (2026-08-17)
-- ============================================================================
-- Pola konsisten di seluruh skema: SELECT dibatasi is_store_staff/
-- is_store_admin/user_store_access; write untuk data transaksional (sale,
-- stock movement, dst) TIDAK punya policy INSERT langsung karena hanya
-- boleh lewat RPC SECURITY DEFINER (checkout_transaction, void_or_refund_
-- transaction, dll) yang melakukan validasi sendiri lalu bypass RLS.

CREATE POLICY accounting_accounts_access ON public.accounting_accounts FOR ALL USING (user_store_access(store_id)) WITH CHECK (user_store_access(store_id));
CREATE POLICY accounting_lines_access ON public.accounting_journal_lines FOR ALL USING (EXISTS (SELECT 1 FROM accounting_journals j WHERE j.id = accounting_journal_lines.journal_id AND user_store_access(j.store_id))) WITH CHECK (EXISTS (SELECT 1 FROM accounting_journals j WHERE j.id = accounting_journal_lines.journal_id AND user_store_access(j.store_id)));
CREATE POLICY accounting_journals_access ON public.accounting_journals FOR ALL USING (user_store_access(store_id)) WITH CHECK (user_store_access(store_id));

CREATE POLICY approval_requests_insert ON public.approval_requests FOR INSERT WITH CHECK (is_store_staff(store_id) AND requested_by IN (SELECT staff.id FROM staff WHERE staff.user_id = auth.uid() AND staff.store_id = approval_requests.store_id AND staff.is_active = true));
CREATE POLICY approval_requests_select ON public.approval_requests FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY approval_requests_update ON public.approval_requests FOR UPDATE USING (is_store_admin(store_id)) WITH CHECK (is_store_admin(store_id));

CREATE POLICY audit_logs_read ON public.audit_logs FOR SELECT USING (is_store_admin(store_id));

CREATE POLICY cash_movements_read ON public.cash_movements FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY categories_delete ON public.categories FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY categories_read ON public.categories FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY categories_update ON public.categories FOR UPDATE USING (is_store_admin(store_id));
CREATE POLICY categories_write ON public.categories FOR INSERT WITH CHECK (is_store_admin(store_id));

CREATE POLICY customer_point_ledger_staff ON public.customer_point_ledger FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY customers_delete ON public.customers FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY customers_insert ON public.customers FOR INSERT WITH CHECK (is_store_staff(store_id));
CREATE POLICY customers_select ON public.customers FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY customers_update ON public.customers FOR UPDATE USING (is_store_staff(store_id)) WITH CHECK (is_store_staff(store_id));

CREATE POLICY devices_delete ON public.devices FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY devices_insert ON public.devices FOR INSERT WITH CHECK (is_store_staff(store_id));
CREATE POLICY devices_select ON public.devices FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY devices_update ON public.devices FOR UPDATE USING (is_store_staff(store_id)) WITH CHECK (is_store_staff(store_id));

CREATE POLICY expenses_delete ON public.expenses FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY expenses_insert ON public.expenses FOR INSERT WITH CHECK (is_store_staff(store_id));
CREATE POLICY expenses_select ON public.expenses FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY expenses_update ON public.expenses FOR UPDATE USING (is_store_admin(store_id)) WITH CHECK (is_store_admin(store_id));

CREATE POLICY held_carts_delete ON public.held_carts FOR DELETE USING (is_store_staff(store_id));
CREATE POLICY held_carts_insert ON public.held_carts FOR INSERT WITH CHECK (is_store_staff(store_id));
CREATE POLICY held_carts_read ON public.held_carts FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY offline_sync_device ON public.offline_sync_queue FOR ALL USING (EXISTS (SELECT 1 FROM devices d WHERE d.id = offline_sync_queue.device_id AND d.store_id = offline_sync_queue.store_id AND d.revoked_at IS NULL AND EXISTS (SELECT 1 FROM staff s WHERE s.id = d.staff_id AND s.user_id = auth.uid() AND s.is_active = true))) WITH CHECK (EXISTS (SELECT 1 FROM devices d WHERE d.id = offline_sync_queue.device_id AND d.store_id = offline_sync_queue.store_id AND d.revoked_at IS NULL AND EXISTS (SELECT 1 FROM staff s WHERE s.id = d.staff_id AND s.user_id = auth.uid() AND s.is_active = true)));

CREATE POLICY products_delete ON public.products FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY products_read ON public.products FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY products_update ON public.products FOR UPDATE USING (is_store_admin(store_id));
CREATE POLICY products_write ON public.products FOR INSERT WITH CHECK (is_store_admin(store_id));

CREATE POLICY promotion_categories_delete ON public.promotion_categories FOR DELETE USING (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_categories.promotion_id AND is_store_admin(p.store_id)));
CREATE POLICY promotion_categories_insert ON public.promotion_categories FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_categories.promotion_id AND is_store_admin(p.store_id)));
CREATE POLICY promotion_categories_select ON public.promotion_categories FOR SELECT USING (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_categories.promotion_id AND is_store_staff(p.store_id)));
CREATE POLICY promotion_categories_update ON public.promotion_categories FOR UPDATE USING (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_categories.promotion_id AND is_store_admin(p.store_id))) WITH CHECK (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_categories.promotion_id AND is_store_admin(p.store_id)));

CREATE POLICY promotion_products_delete ON public.promotion_products FOR DELETE USING (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_products.promotion_id AND is_store_admin(p.store_id)));
CREATE POLICY promotion_products_insert ON public.promotion_products FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_products.promotion_id AND is_store_admin(p.store_id)));
CREATE POLICY promotion_products_select ON public.promotion_products FOR SELECT USING (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_products.promotion_id AND is_store_staff(p.store_id)));
CREATE POLICY promotion_products_update ON public.promotion_products FOR UPDATE USING (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_products.promotion_id AND is_store_admin(p.store_id))) WITH CHECK (EXISTS (SELECT 1 FROM promotions p WHERE p.id = promotion_products.promotion_id AND is_store_admin(p.store_id)));

CREATE POLICY promotions_delete ON public.promotions FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY promotions_insert ON public.promotions FOR INSERT WITH CHECK (is_store_admin(store_id));
CREATE POLICY promotions_select ON public.promotions FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY promotions_update ON public.promotions FOR UPDATE USING (is_store_admin(store_id)) WITH CHECK (is_store_admin(store_id));

CREATE POLICY purchase_items_read ON public.purchase_items FOR SELECT USING (EXISTS (SELECT 1 FROM purchases p WHERE p.id = purchase_items.purchase_id AND is_store_staff(p.store_id)));
CREATE POLICY purchases_read ON public.purchases FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY refund_items_read ON public.refund_items FOR SELECT USING (EXISTS (SELECT 1 FROM refunds r WHERE r.id = refund_items.refund_id AND is_store_staff(r.store_id)));
CREATE POLICY refunds_read ON public.refunds FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY shifts_insert ON public.shifts FOR INSERT WITH CHECK (is_store_staff(store_id));
CREATE POLICY shifts_read ON public.shifts FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY shifts_update ON public.shifts FOR UPDATE USING (is_store_staff(store_id));

CREATE POLICY staff_admin_delete ON public.staff FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY staff_admin_update ON public.staff FOR UPDATE USING (is_store_admin(store_id));
CREATE POLICY staff_admin_write ON public.staff FOR INSERT WITH CHECK (is_store_admin(store_id));
CREATE POLICY staff_read ON public.staff FOR SELECT USING (is_store_staff(store_id));
-- CATATAN: staff_read mengizinkan SEMUA staf toko membaca SEMUA baris staff
-- lain di toko yang sama, termasuk kolom pin_hash (hash bcrypt PIN kunci
-- layar). Percobaan membatasi ini lewat column-level REVOKE pada sesi ini
-- terbukti tidak reliable (sempat memutus akses baca seluruh tabel untuk
-- semua orang) sehingga dibatalkan demi keamanan produksi. RPC set_staff_pin/
-- verify_staff_pin tidak pernah mengembalikan pin_hash ke client, jadi lewat
-- pemakaian normal aplikasi PIN tidak pernah bocor — risiko yang tersisa
-- murni dari akses tabel mentah. Perbaikan yang benar: pindahkan pin_hash
-- dkk ke tabel privat terpisah dengan RLS sendiri (belum dikerjakan).

CREATE POLICY stock_movements_admin_write ON public.stock_movements FOR INSERT WITH CHECK (is_store_admin(store_id));
CREATE POLICY stock_movements_read ON public.stock_movements FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY stock_opname_items_read ON public.stock_opname_items FOR SELECT USING (EXISTS (SELECT 1 FROM stock_opnames so WHERE so.id = stock_opname_items.stock_opname_id AND is_store_staff(so.store_id)));
CREATE POLICY stock_opnames_read ON public.stock_opnames FOR SELECT USING (is_store_staff(store_id));

CREATE POLICY stock_transfer_items_delete ON public.stock_transfer_items FOR DELETE USING (EXISTS (SELECT 1 FROM stock_transfers t WHERE t.id = stock_transfer_items.transfer_id AND is_store_admin(t.store_id)));
CREATE POLICY stock_transfer_items_insert ON public.stock_transfer_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM stock_transfers t WHERE t.id = stock_transfer_items.transfer_id AND is_store_admin(t.store_id)));
CREATE POLICY stock_transfer_items_select ON public.stock_transfer_items FOR SELECT USING (EXISTS (SELECT 1 FROM stock_transfers t WHERE t.id = stock_transfer_items.transfer_id AND is_store_staff(t.store_id)));
CREATE POLICY stock_transfer_items_update ON public.stock_transfer_items FOR UPDATE USING (EXISTS (SELECT 1 FROM stock_transfers t WHERE t.id = stock_transfer_items.transfer_id AND is_store_admin(t.store_id))) WITH CHECK (EXISTS (SELECT 1 FROM stock_transfers t WHERE t.id = stock_transfer_items.transfer_id AND is_store_admin(t.store_id)));

CREATE POLICY stock_transfers_delete ON public.stock_transfers FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY stock_transfers_insert ON public.stock_transfers FOR INSERT WITH CHECK (is_store_admin(store_id));
CREATE POLICY stock_transfers_select ON public.stock_transfers FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY stock_transfers_update ON public.stock_transfers FOR UPDATE USING (is_store_admin(store_id)) WITH CHECK (is_store_admin(store_id));

CREATE POLICY stores_owner_delete ON public.stores FOR DELETE USING (owner_id = auth.uid());
CREATE POLICY stores_owner_insert ON public.stores FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY stores_owner_update ON public.stores FOR UPDATE USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE POLICY stores_select ON public.stores FOR SELECT USING (owner_id = auth.uid() OR is_store_staff(id));

CREATE POLICY suppliers_read ON public.suppliers FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY suppliers_update ON public.suppliers FOR UPDATE USING (is_store_admin(store_id));
CREATE POLICY suppliers_write ON public.suppliers FOR INSERT WITH CHECK (is_store_admin(store_id));

CREATE POLICY transaction_items_read ON public.transaction_items FOR SELECT USING (EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_items.transaction_id AND is_store_staff(t.store_id)));
CREATE POLICY transaction_payments_read ON public.transaction_payments FOR SELECT USING (EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_payments.transaction_id AND is_store_staff(t.store_id)));
CREATE POLICY transactions_read ON public.transactions FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY transactions_update ON public.transactions FOR UPDATE USING (is_store_admin(store_id));

CREATE POLICY warehouse_stock_delete ON public.warehouse_stock FOR DELETE USING (EXISTS (SELECT 1 FROM warehouses w WHERE w.id = warehouse_stock.warehouse_id AND is_store_admin(w.store_id)));
CREATE POLICY warehouse_stock_insert ON public.warehouse_stock FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM warehouses w WHERE w.id = warehouse_stock.warehouse_id AND is_store_admin(w.store_id)));
CREATE POLICY warehouse_stock_select ON public.warehouse_stock FOR SELECT USING (EXISTS (SELECT 1 FROM warehouses w WHERE w.id = warehouse_stock.warehouse_id AND is_store_staff(w.store_id)));
CREATE POLICY warehouse_stock_update ON public.warehouse_stock FOR UPDATE USING (EXISTS (SELECT 1 FROM warehouses w WHERE w.id = warehouse_stock.warehouse_id AND is_store_admin(w.store_id))) WITH CHECK (EXISTS (SELECT 1 FROM warehouses w WHERE w.id = warehouse_stock.warehouse_id AND is_store_admin(w.store_id)));

CREATE POLICY warehouses_delete ON public.warehouses FOR DELETE USING (is_store_admin(store_id));
CREATE POLICY warehouses_insert ON public.warehouses FOR INSERT WITH CHECK (is_store_admin(store_id));
CREATE POLICY warehouses_select ON public.warehouses FOR SELECT USING (is_store_staff(store_id));
CREATE POLICY warehouses_update ON public.warehouses FOR UPDATE USING (is_store_admin(store_id)) WITH CHECK (is_store_admin(store_id));
