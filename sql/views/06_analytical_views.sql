-- ============================================================
-- Bank Loan Risk Analytics | Power BI Source Views
-- ============================================================
SET search_path = loan_risk;

-- ----------------------------------------------------------
-- VIEW 1: vw_loan_summary — Main fact view for Power BI
-- ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_loan_summary AS
SELECT
    fl.loan_id,
    fl.loan_number,
    fl.loan_amount,
    fl.interest_rate,
    fl.tenure_months,
    fl.emi_amount,
    fl.dti_ratio,
    fl.ltv_ratio,
    fl.credit_score_at_origination,
    fl.loan_status,
    fl.is_default,
    fl.days_past_due,
    fl.charged_off_amount,
    fl.recovery_amount,
    fl.risk_grade,
    fl.loan_amount - fl.recovery_amount          AS net_loss_amount,
    -- Application date fields
    app.full_date                                AS application_date,
    app.year                                     AS application_year,
    app.month_name                               AS application_month,
    app.quarter_name                             AS application_quarter,
    -- Disbursal date fields
    dis.full_date                                AS disbursal_date,
    dis.year                                     AS disbursal_year,
    dis.month_num                                AS disbursal_month_num,
    dis.month_name                               AS disbursal_month,
    -- Borrower fields
    b.borrower_name,
    b.gender,
    b.marital_status,
    b.education,
    b.annual_income,
    b.credit_score,
    b.existing_loans_count,
    -- Employment
    e.employment_type,
    e.industry,
    e.stability_score,
    -- Geography
    g.city,
    g.state,
    g.region,
    -- Purpose
    lp.purpose_name,
    lp.purpose_category
FROM fact_loans fl
JOIN dim_borrower    b   ON fl.borrower_id         = b.borrower_id
JOIN dim_employment  e   ON b.employment_id         = e.employment_id
JOIN dim_geography   g   ON b.geography_id          = g.geography_id
JOIN dim_loan_purpose lp ON fl.purpose_id           = lp.purpose_id
JOIN dim_date        app ON fl.application_date_id  = app.date_id
JOIN dim_date        dis ON fl.disbursal_date_id    = dis.date_id;

-- ----------------------------------------------------------
-- VIEW 2: vw_risk_segments — Pre-computed risk banding
-- ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_risk_segments AS
SELECT
    fl.loan_id,
    fl.loan_number,
    fl.risk_grade,
    fl.loan_amount,
    fl.is_default,
    fl.loan_status,
    fl.dti_ratio,
    fl.ltv_ratio,
    fl.credit_score_at_origination,
    e.stability_score,
    -- Composite risk score (0-100)
    ROUND(
        fl.dti_ratio / 55.0 * 30
        + (1 - (fl.credit_score_at_origination - 300.0) / 600) * 40
        + fl.ltv_ratio / 90.0 * 20
        + (10 - e.stability_score) / 9.0 * 10,
    2)                                          AS composite_risk_score,
    CASE
        WHEN ROUND(fl.dti_ratio / 55.0 * 30 + (1 - (fl.credit_score_at_origination - 300.0) / 600) * 40 + fl.ltv_ratio / 90.0 * 20 + (10 - e.stability_score) / 9.0 * 10, 2) < 25 THEN 'Low Risk'
        WHEN ROUND(fl.dti_ratio / 55.0 * 30 + (1 - (fl.credit_score_at_origination - 300.0) / 600) * 40 + fl.ltv_ratio / 90.0 * 20 + (10 - e.stability_score) / 9.0 * 10, 2) < 50 THEN 'Medium Risk'
        WHEN ROUND(fl.dti_ratio / 55.0 * 30 + (1 - (fl.credit_score_at_origination - 300.0) / 600) * 40 + fl.ltv_ratio / 90.0 * 20 + (10 - e.stability_score) / 9.0 * 10, 2) < 75 THEN 'High Risk'
        ELSE 'Very High Risk'
    END                                         AS risk_segment,
    lp.purpose_name,
    e.employment_type,
    g.city,
    g.state
FROM fact_loans fl
JOIN dim_borrower    b   ON fl.borrower_id  = b.borrower_id
JOIN dim_employment  e   ON b.employment_id = e.employment_id
JOIN dim_geography   g   ON b.geography_id  = g.geography_id
JOIN dim_loan_purpose lp ON fl.purpose_id   = lp.purpose_id;

-- ----------------------------------------------------------
-- VIEW 3: vw_monthly_trends — Time-series for line charts
-- ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_monthly_trends AS
SELECT
    dd.year,
    dd.month_num,
    dd.month_name,
    dd.quarter_name,
    TO_DATE(dd.year || '-' || LPAD(dd.month_num::TEXT,2,'0') || '-01', 'YYYY-MM-DD') AS month_start,
    COUNT(fl.loan_id)                            AS loans_disbursed,
    ROUND(SUM(fl.loan_amount) / 1e6, 2)          AS disbursed_cr,
    COUNT(*) FILTER (WHERE fl.is_default)        AS new_defaults,
    ROUND(AVG(fl.interest_rate), 2)              AS avg_rate,
    ROUND(AVG(fl.credit_score_at_origination), 0) AS avg_credit_score,
    ROUND(AVG(fl.dti_ratio), 2)                  AS avg_dti,
    ROUND(100.0 * COUNT(*) FILTER (WHERE fl.is_default) / NULLIF(COUNT(*), 0), 2) AS default_rate_pct
FROM fact_loans fl
JOIN dim_date dd ON fl.disbursal_date_id = dd.date_id
GROUP BY dd.year, dd.month_num, dd.month_name, dd.quarter_name;

-- ----------------------------------------------------------
-- VIEW 4: vw_borrower_profile — Borrower-level aggregated view
-- ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_borrower_profile AS
SELECT
    b.borrower_id,
    b.borrower_name,
    b.gender,
    b.marital_status,
    b.education,
    b.annual_income,
    b.credit_score,
    e.employment_type,
    e.industry,
    g.city,
    g.state,
    g.region,
    COUNT(fl.loan_id)                            AS total_loans,
    ROUND(SUM(fl.loan_amount) / 1e5, 2)          AS total_exposure_lakhs,
    COUNT(*) FILTER (WHERE fl.is_default)        AS default_count,
    ROUND(AVG(fl.dti_ratio), 2)                  AS avg_dti,
    ROUND(AVG(fl.interest_rate), 2)              AS avg_rate,
    MAX(fl.days_past_due)                        AS max_dpd,
    CASE
        WHEN COUNT(*) FILTER (WHERE fl.is_default) > 0 THEN 'Has Default'
        WHEN MAX(fl.days_past_due) > 30 THEN 'Delinquent'
        ELSE 'Clean'
    END                                          AS borrower_risk_flag
FROM dim_borrower b
JOIN dim_employment e ON b.employment_id = e.employment_id
JOIN dim_geography  g ON b.geography_id  = g.geography_id
LEFT JOIN fact_loans fl ON b.borrower_id = fl.borrower_id
GROUP BY b.borrower_id, b.borrower_name, b.gender, b.marital_status, b.education,
         b.annual_income, b.credit_score, e.employment_type, e.industry,
         g.city, g.state, g.region;

-- ----------------------------------------------------------
-- VIEW 5: vw_payment_behavior — Payment patterns per loan
-- ----------------------------------------------------------
CREATE OR REPLACE VIEW vw_payment_behavior AS
SELECT
    fp.loan_id,
    fl.loan_number,
    fl.loan_amount,
    fl.loan_status,
    fl.risk_grade,
    COUNT(fp.payment_id)                          AS total_emis,
    COUNT(*) FILTER (WHERE fp.payment_status = 'Paid')    AS on_time_payments,
    COUNT(*) FILTER (WHERE fp.payment_status = 'Missed')  AS missed_payments,
    COUNT(*) FILTER (WHERE fp.payment_status = 'Partial') AS partial_payments,
    ROUND(AVG(fp.days_delay), 1)                  AS avg_delay_days,
    MAX(fp.days_delay)                            AS max_delay_days,
    ROUND(SUM(fp.amount_paid), 2)                 AS total_collected,
    ROUND(SUM(fp.emi_scheduled), 2)               AS total_scheduled,
    ROUND(100.0 * SUM(fp.amount_paid) / NULLIF(SUM(fp.emi_scheduled), 0), 2) AS collection_rate_pct
FROM fact_payments fp
JOIN fact_loans fl ON fp.loan_id = fl.loan_id
GROUP BY fp.loan_id, fl.loan_number, fl.loan_amount, fl.loan_status, fl.risk_grade;
