-- ============================================================
-- File: 03_seed_lookups.sql  — Reference data
-- ============================================================

-- Risk Tiers
INSERT INTO risk_tiers (tier_code, tier_name, min_score, max_score, risk_weight) VALUES
  ('A',   'Prime',          750, 900, 1.00),
  ('B',   'Near-Prime',     700, 749, 1.15),
  ('C',   'Sub-Prime',      650, 699, 1.35),
  ('D',   'High Risk',      300, 649, 1.60),
  ('NPA', 'Non-Performing', NULL, NULL, 2.50);

-- Branches
INSERT INTO branches (branch_code, branch_name, city, state, region) VALUES
  ('BRN001', 'Mumbai Main',        'Mumbai',     'Maharashtra',  'West'),
  ('BRN002', 'Pune Deccan',        'Pune',        'Maharashtra',  'West'),
  ('BRN003', 'Delhi Connaught',    'New Delhi',   'Delhi',        'North'),
  ('BRN004', 'Gurgaon Cyber City', 'Gurgaon',    'Haryana',      'North'),
  ('BRN005', 'Bengaluru MG Road',  'Bengaluru',  'Karnataka',    'South'),
  ('BRN006', 'Chennai Anna Nagar', 'Chennai',    'Tamil Nadu',   'South'),
  ('BRN007', 'Hyderabad HITEC',    'Hyderabad',  'Telangana',    'South'),
  ('BRN008', 'Kolkata Park Street','Kolkata',    'West Bengal',  'East'),
  ('BRN009', 'Ahmedabad CG Road',  'Ahmedabad',  'Gujarat',      'West'),
  ('BRN010', 'Jaipur MI Road',     'Jaipur',     'Rajasthan',    'North');

-- Loan Products
INSERT INTO loan_products
  (product_code, product_name, product_type, min_amount, max_amount,
   min_tenure_months, max_tenure_months, base_rate, is_secured) VALUES
  ('HOME-STD',  'Standard Home Loan',       'Home',      500000, 50000000, 60, 300, 8.50,  TRUE),
  ('HOME-AFD',  'Affordable Housing Loan',  'Home',      200000, 3500000,  60, 240, 9.00,  TRUE),
  ('AUTO-NEW',  'New Car Loan',             'Auto',      100000, 5000000,  12, 84,  8.75,  TRUE),
  ('AUTO-USED', 'Used Car Loan',            'Auto',       50000, 2000000,  12, 60,  11.50, TRUE),
  ('PERS-SAL',  'Personal Loan – Salaried', 'Personal',   25000, 1500000,  12, 60,  12.50, FALSE),
  ('PERS-SE',   'Personal Loan – Self Emp', 'Personal',   25000, 1000000,  12, 48,  14.50, FALSE),
  ('BIZ-WC',    'Business Working Capital', 'Business',  100000, 10000000, 12, 60,  13.00, FALSE),
  ('BIZ-TL',    'Business Term Loan',       'Business',  200000, 25000000, 24, 120, 12.00, TRUE),
  ('EDU-DOM',   'Education Loan – Domestic','Education',  50000, 2000000,  12, 84,  10.00, FALSE),
  ('EDU-ABR',   'Education Loan – Abroad',  'Education', 200000, 7500000,  12, 120, 11.00, FALSE);
