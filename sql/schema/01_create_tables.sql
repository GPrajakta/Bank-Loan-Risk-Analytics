-- ============================================================
-- Bank Loan Risk Analytics | Schema: Dimension & Fact Tables
-- Author: Prajakta Gitte | Database: PostgreSQL 15+
-- ============================================================

-- Drop and recreate schema for clean setup
DROP SCHEMA IF EXISTS loan_risk CASCADE;
CREATE SCHEMA loan_risk;
SET search_path = loan_risk;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- DIM: Geography
CREATE TABLE dim_geography (
    geography_id    SERIAL PRIMARY KEY,
    city            VARCHAR(100),
    state           VARCHAR(100),
    region          VARCHAR(50),  -- North / South / East / West
    zip_code        VARCHAR(10),
    country         VARCHAR(50) DEFAULT 'India'
);

-- DIM: Employment
CREATE TABLE dim_employment (
    employment_id   SERIAL PRIMARY KEY,
    employment_type VARCHAR(50),  -- Salaried / Self-Employed / Business / Unemployed
    industry        VARCHAR(100),
    stability_score INT CHECK (stability_score BETWEEN 1 AND 10)
    -- 1=high risk, 10=most stable
);

-- DIM: Loan Purpose
CREATE TABLE dim_loan_purpose (
    purpose_id      SERIAL PRIMARY KEY,
    purpose_name    VARCHAR(100),  -- Home Loan / Car Loan / Education / Personal / Business
    purpose_category VARCHAR(50),  -- Secured / Unsecured
    base_risk_weight NUMERIC(3,2)  -- Relative default risk weight
);

-- DIM: Borrower
CREATE TABLE dim_borrower (
    borrower_id         SERIAL PRIMARY KEY,
    borrower_name       VARCHAR(150),
    date_of_birth       DATE,
    gender              VARCHAR(20),
    marital_status      VARCHAR(20),
    dependents          INT DEFAULT 0,
    education           VARCHAR(50),  -- Graduate / Post-Graduate / High School
    geography_id        INT REFERENCES dim_geography(geography_id),
    employment_id       INT REFERENCES dim_employment(employment_id),
    annual_income       NUMERIC(15,2),
    monthly_income      NUMERIC(12,2) GENERATED ALWAYS AS (annual_income / 12) STORED,
    credit_score        INT CHECK (credit_score BETWEEN 300 AND 900),
    existing_loans_count INT DEFAULT 0,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DIM: Date (calendar table for Power BI time intelligence)
CREATE TABLE dim_date (
    date_id         INT PRIMARY KEY,       -- YYYYMMDD format
    full_date       DATE NOT NULL,
    day_of_week     INT,
    day_name        VARCHAR(10),
    week_of_year    INT,
    month_num       INT,
    month_name      VARCHAR(10),
    quarter         INT,
    quarter_name    VARCHAR(6),
    year            INT,
    fiscal_year     INT,                   -- April-March FY
    fiscal_quarter  INT,
    is_weekend      BOOLEAN,
    is_holiday      BOOLEAN DEFAULT FALSE
);

-- ============================================================
-- FACT TABLES
-- ============================================================

-- FACT: Loans (grain = one row per loan)
CREATE TABLE fact_loans (
    loan_id             SERIAL PRIMARY KEY,
    loan_number         VARCHAR(20) UNIQUE NOT NULL,  -- e.g. LN-2024-00001
    borrower_id         INT REFERENCES dim_borrower(borrower_id),
    purpose_id          INT REFERENCES dim_loan_purpose(purpose_id),

    -- Application details
    application_date_id INT REFERENCES dim_date(date_id),
    disbursal_date_id   INT REFERENCES dim_date(date_id),
    maturity_date_id    INT REFERENCES dim_date(date_id),

    -- Loan financials
    loan_amount         NUMERIC(15,2) NOT NULL,
    interest_rate       NUMERIC(5,2) NOT NULL,         -- Annual %
    tenure_months       INT NOT NULL,
    emi_amount          NUMERIC(12,2),                  -- Equated Monthly Installment
    total_payable       NUMERIC(15,2),

    -- Risk metrics at origination
    credit_score_at_origination  INT,
    dti_ratio                    NUMERIC(5,2),          -- Debt-to-Income %
    ltv_ratio                    NUMERIC(5,2),          -- Loan-to-Value %
    collateral_value             NUMERIC(15,2),

    -- Status & outcome
    loan_status         VARCHAR(30) NOT NULL,
    -- Values: 'Current', 'Closed', 'Default', 'NPA', '30DPD', '60DPD', '90DPD'
    is_default          BOOLEAN GENERATED ALWAYS AS (loan_status IN ('Default','NPA')) STORED,
    days_past_due       INT DEFAULT 0,
    default_date_id     INT REFERENCES dim_date(date_id),
    charged_off_amount  NUMERIC(15,2) DEFAULT 0,
    recovery_amount     NUMERIC(15,2) DEFAULT 0,

    -- Approval metadata
    approved_by         VARCHAR(100),
    risk_grade          VARCHAR(5),  -- A, B, C, D, E
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- FACT: Payments (grain = one row per EMI payment)
CREATE TABLE fact_payments (
    payment_id          SERIAL PRIMARY KEY,
    loan_id             INT REFERENCES fact_loans(loan_id),
    payment_date_id     INT REFERENCES dim_date(date_id),
    due_date_id         INT REFERENCES dim_date(date_id),
    emi_scheduled       NUMERIC(12,2),
    principal_component NUMERIC(12,2),
    interest_component  NUMERIC(12,2),
    amount_paid         NUMERIC(12,2),
    payment_status      VARCHAR(20),  -- 'Paid', 'Partial', 'Missed', 'Prepaid'
    days_delay          INT DEFAULT 0,
    outstanding_balance NUMERIC(15,2),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- INDEXES for query performance
-- ============================================================
CREATE INDEX idx_fact_loans_borrower    ON fact_loans(borrower_id);
CREATE INDEX idx_fact_loans_status      ON fact_loans(loan_status);
CREATE INDEX idx_fact_loans_appdate     ON fact_loans(application_date_id);
CREATE INDEX idx_fact_loans_risk_grade  ON fact_loans(risk_grade);
CREATE INDEX idx_fact_payments_loan     ON fact_payments(loan_id);
CREATE INDEX idx_fact_payments_date     ON fact_payments(payment_date_id);
CREATE INDEX idx_borrower_credit        ON dim_borrower(credit_score);
CREATE INDEX idx_borrower_income        ON dim_borrower(annual_income);

-- ============================================================
-- Generate dim_date for 2020-01-01 to 2026-12-31
-- ============================================================
INSERT INTO dim_date (
    date_id, full_date, day_of_week, day_name, week_of_year,
    month_num, month_name, quarter, quarter_name, year,
    fiscal_year, fiscal_quarter, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d,
    EXTRACT(DOW FROM d)::INT,
    TO_CHAR(d, 'Day'),
    EXTRACT(WEEK FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'Month'),
    EXTRACT(QUARTER FROM d)::INT,
    'Q' || EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(YEAR FROM d)::INT,
    CASE WHEN EXTRACT(MONTH FROM d) >= 4
         THEN EXTRACT(YEAR FROM d)::INT
         ELSE EXTRACT(YEAR FROM d)::INT - 1 END,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (4,5,6)   THEN 1
        WHEN EXTRACT(MONTH FROM d) IN (7,8,9)   THEN 2
        WHEN EXTRACT(MONTH FROM d) IN (10,11,12) THEN 3
        ELSE 4 END,
    EXTRACT(DOW FROM d) IN (0, 6)
FROM generate_series('2020-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS d;

COMMENT ON TABLE fact_loans    IS 'Grain: One row per loan application/disbursement';
COMMENT ON TABLE fact_payments IS 'Grain: One row per EMI payment event';
COMMENT ON TABLE dim_borrower  IS 'Borrower demographics and financial profile';
COMMENT ON TABLE dim_date      IS 'Calendar dimension for time-intelligence in Power BI';
