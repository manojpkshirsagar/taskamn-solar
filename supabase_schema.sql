-- SQL DDL for Siya Solar Task Manager & CRM

-- 1. Enable UUID Extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create Employees Table (linked to auth.users if needed)
CREATE TABLE IF NOT EXISTS public.employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    mobile_number TEXT NOT NULL UNIQUE,
    designation TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('admin', 'employee')),
    employee_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create Customers Table
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    mobile_number TEXT NOT NULL,
    email_address TEXT,
    address TEXT NOT NULL DEFAULT '',
    consumer_number TEXT,
    solar_capacity NUMERIC DEFAULT 0,
    stage TEXT NOT NULL DEFAULT 'Lead' CHECK (
        stage IN (
            'Lead', 'Survey', 'Quotation', 'Quotation Sent', 'Customer Confirmed',
            'PM Surya Ghar Application', 'Loan Process', 'Approved',
            'Material Dispatch', 'Installation', 'Net Meter', 'RTS',
            'Subsidy', 'Completed', 'Cancelled'
        )
    ),
    installation_stage INT NOT NULL DEFAULT 1 CHECK (installation_stage BETWEEN 1 AND 10),
    payment_mode TEXT NOT NULL DEFAULT 'Not Selected',
    -- Human-readable custom IDs
    customer_code TEXT,
    lead_code TEXT,
    installation_code TEXT,
    net_meter_code TEXT,
    subsidy_code TEXT,
    quotation_code TEXT,
    payment_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create Tasks Table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    task_type TEXT NOT NULL,
    assigned_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    due_date DATE NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High')),
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Completed', 'Hold')),
    task_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create Service Requests / Complaints Table
CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    mobile_number TEXT NOT NULL,
    complaint_type TEXT NOT NULL,
    description TEXT NOT NULL,
    photo_url TEXT,
    status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'Assigned', 'Resolved', 'Closed')),
    service_request_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Loans Table
CREATE TABLE IF NOT EXISTS public.loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    loan_amount NUMERIC NOT NULL DEFAULT 0,
    bank_name TEXT NOT NULL,
    branch TEXT,
    system_capacity TEXT,
    status TEXT NOT NULL DEFAULT 'Loan Application',
    assigned_employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
    remarks TEXT,
    loan_code TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Loan Tasks Table
CREATE TABLE IF NOT EXISTS public.loan_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
    task_type TEXT NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Create Installation Photos Table
CREATE TABLE IF NOT EXISTS public.installation_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID UNIQUE NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    roof_photo_url TEXT,
    installation_photo_url TEXT,
    inverter_photo_url TEXT,
    meter_photo_url TEXT,
    customer_signature_url TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Create Import History Table
CREATE TABLE IF NOT EXISTS public.import_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name TEXT NOT NULL,
    module_name TEXT NOT NULL,
    import_date TIMESTAMPTZ DEFAULT NOW(),
    imported_by TEXT NOT NULL DEFAULT 'Admin',
    success_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0
);

-- 8. Create Export History Table
CREATE TABLE IF NOT EXISTS public.export_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_name TEXT NOT NULL,
    export_type TEXT NOT NULL,
    export_date TIMESTAMPTZ DEFAULT NOW(),
    exported_by TEXT NOT NULL DEFAULT 'Admin',
    total_records INT NOT NULL DEFAULT 0
);

-- 9. Insert Demo Admin & Employee for testing
-- Note: Replace these or link to proper Supabase auth.users in production
INSERT INTO public.employees (id, name, mobile_number, designation, role)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Admin User', '9876543210', 'Solar Manager', 'admin'),
    ('22222222-2222-2222-2222-222222222222', 'Rohan Shinde', '8888888888', 'Field Technician', 'employee')
ON CONFLICT (mobile_number) DO NOTHING;
