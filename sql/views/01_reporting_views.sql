-- ============================================================
-- BANK LOAN RISK ANALYTICS — Reporting Views
-- File: views/01_reporting_views.sql
-- These views are imported directly into Power BI
-- ============================================================

-- ─────────────────────────────────────────
-- V1: MASTER LOAN VIEW
--     Single flat table for Power BI import
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW vw_loan_master AS
SELECT
    la.account_id,
    la.account_no,
    la.disbursal_date,
    la.maturity_date,
    DATE_PART('year', AGE(CURRENT_DATE, la.disbursal_date)) * 12 +
    DATE_PART('month', AGE(CURRENT_DATE, la.disbursal_date))     AS months_on_books,
    la.principal_amount,
    la.outstanding_balance,
    la.interest_rate,
    la.tenure_months,
    la.emi_amount,
    la.account_status,
    la.npa_date,
    la.npa_bucket,
    la.dpd_current,
    la.dpd_max_ever,
    la.ltv_ratio,
    -- Product
    lp.product_type,
    lp.product_name,
    lp.product_code,
    lp.is_secured,
    -- Risk tier
    rt.tier_code,
    rt.tier_name,
    -- Branch
    br.branch_name,
    br.city        AS branch_city,
    br.state       AS branch_state,
    br.region,
    -- Borrower
    b.borrower_id,
    b.borrower_code,
    b.full_name,
    DATE_PART('year', AGE(CURRENT_DATE, b.date_of_birth))::INT  AS borrower_age,
    b.gender,
    b.employment_type,
    b.annual_income,
    b.credit_score,
    b.existing_emi,
    b.city         AS borrower_city,
    b.state        AS borrower_state,
    -- Derived fields
    CASE
        WHEN b.credit_score >= 750 THEN 'Prime (750+)'
        WHEN b.credit_score >= 700 THEN 'Near-Prime (700-749)'
        WHEN b.credit_score >= 650 THEN 'Sub-Prime (650-699)'
        ELSE 'High Risk (<650)'
    END AS credit_score_band,
    CASE
        WHEN b.annual_income < 300000  THEN 'Below 3L'
        WHEN b.annual_income < 600000  THEN '3L-6L'
        WHEN b.annual_income < 1000000 THEN '6L-10L'
        WHEN b.annual_income < 2000000 THEN '10L-20L'
        ELSE 'Above 20L'
    END AS income_band,
    CASE
        WHEN la.dpd_current = 0              THEN '0-Current'
        WHEN la.dpd_current BETWEEN 1  AND 30 THEN '1-30 DPD'
        WHEN la.dpd_current BETWEEN 31 AND 60 THEN '31-60 DPD'
        WHEN la.dpd_current BETWEEN 61 AND 90 THEN '61-90 DPD'
        ELSE '90+ DPD'
    END AS dpd_bucket,
    CASE
        WHEN la.account_status IN ('NPA','Written Off') THEN 1 ELSE 0
    END AS is_defaulted,
    ROUND((b.existing_emi + la.emi_amount) /
          NULLIF(b.annual_income / 12.0, 0) * 100, 2) AS dscr_ratio
FROM loan_accounts  la
JOIN loan_products  lp ON lp.product_id = la.product_id
JOIN risk_tiers     rt ON rt.tier_id    = la.tier_id
JOIN branches       br ON br.branch_id  = la.branch_id
JOIN borrowers       b ON  b.borrower_id = la.borrower_id;


-- ─────────────────────────────────────────
-- V2: MONTHLY PAYMENT SUMMARY VIEW
--     For collection trend analysis in PBI
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW vw_monthly_collections AS
SELECT
    DATE_TRUNC('month', lp.due_date)::DATE              AS collection_month,
    la.product_id,
    pr.product_type,
    la.branch_id,
    br.region,
    COUNT(lp.payment_id)                                 AS emi_count,
    SUM(lp.emi_due)                                      AS total_emi_due,
    SUM(lp.amount_paid)                                  AS total_collected,
    SUM(lp.emi_due - lp.amount_paid)                     AS shortfall,
    SUM(lp.penalty_charged)                              AS total_penalty,
    SUM(CASE WHEN lp.payment_status = 'Paid'    THEN 1 ELSE 0 END) AS paid_count,
    SUM(CASE WHEN lp.payment_status = 'Partial' THEN 1 ELSE 0 END) AS partial_count,
    SUM(CASE WHEN lp.payment_status = 'Overdue' THEN 1 ELSE 0 END) AS overdue_count,
    ROUND(100.0 * SUM(lp.amount_paid)
                / NULLIF(SUM(lp.emi_due), 0), 2)         AS collection_rate_pct
FROM loan_payments  lp
JOIN loan_accounts  la ON la.account_id = lp.account_id
JOIN loan_products  pr ON pr.product_id = la.product_id
JOIN branches       br ON br.branch_id  = la.branch_id
GROUP BY 1, 2, 3, 4, 5;


-- ─────────────────────────────────────────
-- V3: APPLICATION FUNNEL VIEW
--     Approval / rejection pipeline
-- ─────────────────────────────────────────
CREATE OR REPLACE VIEW vw_application_funnel AS
SELECT
    DATE_TRUNC('month', app.application_date)::DATE     AS app_month,
    lp.product_type,
    br.region,
    app.status,
    COUNT(app.application_id)                           AS app_count,
    SUM(app.applied_amount)                             AS applied_amount,
    SUM(app.approved_amount)                            AS approved_amount,
    ROUND(100.0 * COUNT(CASE WHEN app.status = 'Disbursed'
                             THEN 1 END)
                / NULLIF(COUNT(*), 0), 2)               AS conversion_rate_pct
FROM loan_applications  app
JOIN loan_products       lp ON lp.product_id = app.product_id
JOIN branches            br ON br.branch_id  = app.branch_id
GROUP BY 1, 2, 3, 4;
