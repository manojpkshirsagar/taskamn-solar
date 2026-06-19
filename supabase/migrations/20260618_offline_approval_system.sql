-- Migration: offline_approval_system
-- Adds sync_queue, pending_approvals, and payments tables
-- for the Offline Mode + Employee Approval Workflow feature.

-- ============================================================
-- 1. SYNC QUEUE TABLE (cloud mirror of local sync queue)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.sync_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL CHECK (action_type IN ('CREATE', 'UPDATE', 'DELETE')),
  data_json JSONB,
  sync_status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (sync_status IN ('Pending', 'Syncing', 'Success', 'Failed')),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.sync_queue ENABLE ROW LEVEL SECURITY;

-- Employees can insert their own sync records; admins can see all
CREATE POLICY "Employees insert own sync records" ON public.sync_queue
  FOR INSERT TO authenticated
  WITH CHECK (employee_id = (SELECT auth.uid()));

CREATE POLICY "Employees see own sync records" ON public.sync_queue
  FOR SELECT TO authenticated
  USING (
    employee_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.employees
      WHERE id = (SELECT auth.uid()) AND role = 'admin'
    )
  );

CREATE POLICY "Employees update own sync records" ON public.sync_queue
  FOR UPDATE TO authenticated
  USING (employee_id = (SELECT auth.uid()))
  WITH CHECK (employee_id = (SELECT auth.uid()));

-- ============================================================
-- 2. PENDING APPROVALS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pending_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL CHECK (action_type IN ('CREATE', 'UPDATE', 'DELETE')),
  old_data JSONB,
  new_data JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending', 'Approved', 'Rejected')),
  rejection_reason TEXT,
  approved_by UUID REFERENCES public.employees(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.pending_approvals ENABLE ROW LEVEL SECURITY;

-- Employees can insert and see their own approvals
CREATE POLICY "Employees insert own approvals" ON public.pending_approvals
  FOR INSERT TO authenticated
  WITH CHECK (employee_id = (SELECT auth.uid()));

CREATE POLICY "Employees see own approvals" ON public.pending_approvals
  FOR SELECT TO authenticated
  USING (
    employee_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.employees
      WHERE id = (SELECT auth.uid()) AND role = 'admin'
    )
  );

-- Only admins can update approval status
CREATE POLICY "Admins update approval status" ON public.pending_approvals
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE id = (SELECT auth.uid()) AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE id = (SELECT auth.uid()) AND role = 'admin'
    )
  );

-- ============================================================
-- 3. PAYMENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  payment_mode TEXT NOT NULL DEFAULT 'Cash'
    CHECK (payment_mode IN ('Cash', 'Cheque', 'Online', 'Bank Transfer')),
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  receipt_number TEXT,
  remarks TEXT,
  payment_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- All authenticated users can see payments; only admins can directly write
CREATE POLICY "Authenticated users see payments" ON public.payments
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admins write payments" ON public.payments
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE id = (SELECT auth.uid()) AND role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.employees
      WHERE id = (SELECT auth.uid()) AND role = 'admin'
    )
  );

-- ============================================================
-- 4. GRANT DATA API ACCESS
-- ============================================================
GRANT SELECT, INSERT, UPDATE ON public.sync_queue TO authenticated;
GRANT SELECT, INSERT ON public.pending_approvals TO authenticated;
GRANT UPDATE ON public.pending_approvals TO authenticated;
GRANT SELECT ON public.payments TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.payments TO authenticated;
