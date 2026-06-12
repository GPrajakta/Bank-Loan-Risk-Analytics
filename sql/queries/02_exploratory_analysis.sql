-- ============================================================
-- Bank Loan Risk Analytics | Exploratory Data Analysis
-- ============================================================
SET search_path = loan_risk;

-- ----------------------------------------------------------
-- Q1: Portfolio Overview — Total loans, amounts, status mix
-- ----------------------------------------------------------
SELECT
    COUNT(*)                                          AS total_loans,
    COUNT(*) FILTER (WHERE loan_status = 'Current')  AS active_loans,
    COUNT(*) FILTER (WHERE loan_status = 'Closed')   AS closed_loans,
    COUNT(*) FILTER (WHERE is_default = TRUE)        AS defaulted_loans,
    ROUND(SUM(loan_amount) / 1e6, 2)                 AS total_portfolio_cr,
    ROUND(AVG(loan_amount), 0)                       AS avg_loan_amount,
    ROUND(AVG(interest_rate), 2)                     AS avg_interest_rate,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE is_default = TRUE) / COUNT(*),
        2
    )                                                AS default_rate_pct
FROM fact_loans;

-- ----------------------------------------------------------
-- Q2: Loan distribution by Risk Grade
-- ----------------------------------------------------------
SELECT
    risk_grade,
    COUNT(*)                              AS loan_count,
    ROUND(SUM(loan_amount) / 1e6, 2)      AS total_amount_cr,
    ROUND(AVG(interest_rate), 2)          AS avg_rate,
    ROUND(AVG(credit_score_at_origination), 0) AS avg_credit_score,
    COUNT(*) FILTER (WHERE is_default)    AS defaults,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE is_default) / COUNT(*), 2
    )                                     AS default_rate_pct
FROM fact_loans
GROUP BY risk_grade
ORDER BY risk_grade;

-- ----------------------------------------------------------
-- Q3: Default rate by Loan Purpose
-- ----------------------------------------------------------
SELECT
    lp.purpose_name,
    lp.purpose_category,
    COUNT(fl.loan_id)                     AS total_loans,
    COUNT(*) FILTER (WHERE fl.is_default) AS defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE fl.is_default) / COUNT(*), 2) AS default_rate_pct,
    ROUND(SUM(fl.loan_amount) / 1e6, 2)   AS portfolio_cr,
    ROUND(AVG(fl.dti_ratio), 2)           AS avg_dti
FROM fact_loans fl
JOIN dim_loan_purpose lp ON fl.purpose_id = lp.purpose_id
GROUP BY lp.purpose_name, lp.purpose_category
ORDER BY default_rate_pct DESC;

-- ----------------------------------------------------------
-- Q4: Credit Score distribution buckets
-- ----------------------------------------------------------
SELECT
    CASE
        WHEN credit_score_at_origination < 580  THEN '< 580 (Poor)'
        WHEN credit_score_at_origination < 670  THEN '580–669 (Fair)'
        WHEN credit_score_at_origination < 740  THEN '670–739 (Good)'
        WHEN credit_score_at_origination < 800  THEN '740–799 (Very Good)'
        ELSE '800+ (Excellent)'
    END                                               AS credit_band,
    COUNT(*)                                          AS loan_count,
    ROUND(AVG(interest_rate), 2)                      AS avg_rate,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_default) / COUNT(*), 2) AS default_pct
FROM fact_loans
GROUP BY credit_band
ORDER BY MIN(credit_score_at_origination);

-- ----------------------------------------------------------
-- Q5: Monthly disbursement trend (2022-2024)
-- ----------------------------------------------------------
SELECT
    dd.year,
    dd.month_name,
    dd.month_num,
    COUNT(fl.loan_id)                     AS loans_disbursed,
    ROUND(SUM(fl.loan_amount) / 1e6, 2)   AS amount_cr,
    ROUND(AVG(fl.interest_rate), 2)       AS avg_rate
FROM fact_loans fl
JOIN dim_date dd ON fl.disbursal_date_id = dd.date_id
GROUP BY dd.year, dd.month_name, dd.month_num
ORDER BY dd.year, dd.month_num;

-- ----------------------------------------------------------
-- Q6: Top 10 borrowers by exposure
-- ----------------------------------------------------------
SELECT
    b.borrower_id,
    b.borrower_name,
    b.credit_score,
    b.annual_income,
    COUNT(fl.loan_id)                     AS total_loans,
    ROUND(SUM(fl.loan_amount) / 1e5, 2)   AS total_exposure_lakhs,
    COUNT(*) FILTER (WHERE fl.is_default) AS defaults
FROM fact_loans fl
JOIN dim_borrower b ON fl.borrower_id = b.borrower_id
GROUP BY b.borrower_id, b.borrower_name, b.credit_score, b.annual_income
ORDER BY total_exposure_lakhs DESC
LIMIT 10;
