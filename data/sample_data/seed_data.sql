-- ============================================================
-- Seed Data — 500 synthetic loans (realistic distributions)
-- ============================================================
SET search_path = loan_risk;

-- Geography
INSERT INTO dim_geography (city, state, region, zip_code) VALUES
('Mumbai',    'Maharashtra',  'West',  '400001'),
('Pune',      'Maharashtra',  'West',  '411001'),
('Delhi',     'Delhi',        'North', '110001'),
('Bengaluru', 'Karnataka',    'South', '560001'),
('Chennai',   'Tamil Nadu',   'South', '600001'),
('Hyderabad', 'Telangana',    'South', '500001'),
('Kolkata',   'West Bengal',  'East',  '700001'),
('Ahmedabad', 'Gujarat',      'West',  '380001'),
('Jaipur',    'Rajasthan',    'North', '302001'),
('Nagpur',    'Maharashtra',  'West',  '440001');

-- Employment
INSERT INTO dim_employment (employment_type, industry, stability_score) VALUES
('Salaried',      'IT / Software',          9),
('Salaried',      'Banking & Finance',       8),
('Salaried',      'Government / PSU',       10),
('Salaried',      'Healthcare',              7),
('Salaried',      'Manufacturing',           6),
('Self-Employed', 'Retail / Trade',          5),
('Self-Employed', 'Professional Services',   6),
('Business',      'MSME',                    5),
('Business',      'Real Estate',             4),
('Unemployed',    'N/A',                     1);

-- Loan Purpose
INSERT INTO dim_loan_purpose (purpose_name, purpose_category, base_risk_weight) VALUES
('Home Loan',          'Secured',   0.05),
('Car Loan',           'Secured',   0.08),
('Education Loan',     'Unsecured', 0.12),
('Personal Loan',      'Unsecured', 0.18),
('Business Loan',      'Secured',   0.14),
('Gold Loan',          'Secured',   0.04),
('Two-Wheeler Loan',   'Secured',   0.10),
('Medical Loan',       'Unsecured', 0.16),
('Agriculture Loan',   'Secured',   0.09),
('Debt Consolidation', 'Unsecured', 0.20);

-- 30 Borrowers
INSERT INTO dim_borrower (
    borrower_name, date_of_birth, gender, marital_status,
    dependents, education, geography_id, employment_id,
    annual_income, credit_score, existing_loans_count
)
SELECT
    'Borrower_' || n,
    DATE '1975-01-01' + (n * 87 % 7300) * INTERVAL '1 day',
    CASE n % 3 WHEN 0 THEN 'Male' WHEN 1 THEN 'Female' ELSE 'Male' END,
    CASE n % 4 WHEN 0 THEN 'Single' ELSE 'Married' END,
    n % 4,
    CASE n % 3 WHEN 0 THEN 'Graduate' WHEN 1 THEN 'Post-Graduate' ELSE 'High School' END,
    (n % 10) + 1,
    (n % 9) + 1,
    (300000 + (n * 43211 % 2000000))::NUMERIC(15,2),
    LEAST(900, 500 + (n * 137 % 400)),
    n % 4
FROM generate_series(1, 30) AS n;

-- 500 Loans
INSERT INTO fact_loans (
    loan_number, borrower_id, purpose_id,
    application_date_id, disbursal_date_id, maturity_date_id,
    loan_amount, interest_rate, tenure_months, emi_amount, total_payable,
    credit_score_at_origination, dti_ratio, ltv_ratio, collateral_value,
    loan_status, days_past_due, charged_off_amount, recovery_amount,
    approved_by, risk_grade
)
SELECT
    'LN-' || LPAD(n::TEXT, 5, '0'),
    (n % 30) + 1,
    (n % 10) + 1,
    TO_CHAR(DATE '2022-01-01' + (n * 17 % 730) * INTERVAL '1 day', 'YYYYMMDD')::INT,
    TO_CHAR(DATE '2022-01-15' + (n * 17 % 730) * INTERVAL '1 day', 'YYYYMMDD')::INT,
    TO_CHAR(DATE '2024-01-15' + (n * 17 % 730) * INTERVAL '1 day' + ((12 + n % 120) * INTERVAL '1 month'), 'YYYYMMDD')::INT,
    ROUND((50000 + (n * 98237 % 4950000))::NUMERIC / 1000) * 1000,
    ROUND((7.5 + (n * 0.107) % 10.5)::NUMERIC, 2),
    (ARRAY[12,24,36,60,84,120,180,240])[((n % 8) + 1)],
    ROUND((50000 + (n * 98237 % 4950000)) / (12 + n % 120) * (1 + (7.5 + (n * 0.107) % 10.5) / 1200 * (12 + n % 120))::NUMERIC, 2),
    ROUND((50000 + (n * 98237 % 4950000)) * (1 + (7.5 + (n * 0.107) % 10.5) / 100)::NUMERIC, 2),
    LEAST(900, 500 + ((n % 30 + 1) * 137 % 400)),
    ROUND((10 + (n * 0.45) % 45)::NUMERIC, 2),
    ROUND((30 + (n * 0.6) % 60)::NUMERIC, 2),
    ROUND((100000 + (n * 112543 % 10000000))::NUMERIC, 2),
    CASE
        WHEN n % 20 IN (0,1,2) THEN 'Default'
        WHEN n % 20 IN (3)     THEN 'NPA'
        WHEN n % 20 IN (4,5)   THEN '30DPD'
        WHEN n % 20 IN (6)     THEN '60DPD'
        WHEN n % 20 IN (7)     THEN '90DPD'
        WHEN n % 20 IN (8,9,10) THEN 'Closed'
        ELSE 'Current'
    END,
    CASE
        WHEN n % 20 IN (0,1,2,3) THEN 90 + (n % 180)
        WHEN n % 20 IN (4,5)     THEN 30 + (n % 30)
        WHEN n % 20 IN (6)       THEN 60 + (n % 30)
        WHEN n % 20 IN (7)       THEN 90 + (n % 30)
        ELSE 0
    END,
    CASE WHEN n % 20 IN (0,1,2,3) THEN ROUND((50000 + (n * 98237 % 4950000)) * 0.6::NUMERIC, 2) ELSE 0 END,
    CASE WHEN n % 20 IN (0,1,2,3) THEN ROUND((50000 + (n * 98237 % 4950000)) * 0.21::NUMERIC, 2) ELSE 0 END,
    'Officer_' || ((n % 5) + 1),
    (ARRAY['A','A','B','B','C','C','D','E'])[((n % 8) + 1)]
FROM generate_series(1, 500) AS n;

-- 3000 Payment records
INSERT INTO fact_payments (
    loan_id, payment_date_id, due_date_id,
    emi_scheduled, principal_component, interest_component,
    amount_paid, payment_status, days_delay, outstanding_balance
)
SELECT
    l.loan_id,
    TO_CHAR(DATE '2022-02-01' + (p * 30 * INTERVAL '1 day'), 'YYYYMMDD')::INT,
    TO_CHAR(DATE '2022-02-01' + (p * 30 * INTERVAL '1 day') - INTERVAL '2 days', 'YYYYMMDD')::INT,
    l.emi_amount,
    ROUND(l.emi_amount * 0.4, 2),
    ROUND(l.emi_amount * 0.6, 2),
    CASE
        WHEN l.loan_status IN ('Default','NPA') AND p > 3 THEN 0
        ELSE l.emi_amount
    END,
    CASE
        WHEN l.loan_status IN ('Default','NPA') AND p > 3 THEN 'Missed'
        WHEN l.loan_status = '30DPD' AND p = 6 THEN 'Partial'
        ELSE 'Paid'
    END,
    CASE
        WHEN l.loan_status IN ('Default','NPA') AND p > 3 THEN 30 + (l.loan_id % 60)
        WHEN l.loan_status = '30DPD' AND p = 6 THEN 30
        ELSE 0
    END,
    GREATEST(0, l.loan_amount - (p * l.emi_amount * 0.4))
FROM fact_loans l
CROSS JOIN generate_series(1, 6) AS p
WHERE l.loan_id <= 500;

SELECT 'Seed loaded: ' ||
    (SELECT COUNT(*) FROM dim_borrower) || ' borrowers, ' ||
    (SELECT COUNT(*) FROM fact_loans)   || ' loans, ' ||
    (SELECT COUNT(*) FROM fact_payments)|| ' payments' AS status;
