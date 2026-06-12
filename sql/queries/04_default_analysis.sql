-- ============================================================
-- Bank Loan Risk Analytics | Default & NPA Deep Dive
-- ============================================================
SET search_path = loan_risk;

-- ----------------------------------------------------------
-- Q11: Default rate by Employment Type
-- ----------------------------------------------------------
SELECT
    e.employment_type,
    e.industry,
    e.stability_score,
    COUNT(fl.loan_id)                              AS total_loans,
    COUNT(*) FILTER (WHERE fl.is_default)          AS defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE fl.is_default) / COUNT(*), 2) AS default_rate_pct,
    ROUND(AVG(fl.interest_rate), 2)                AS avg_rate,
    ROUND(AVG(fl.dti_ratio), 2)                    AS avg_dti
FROM fact_loans fl
JOIN dim_borrower b   ON fl.borrower_id  = b.borrower_id
JOIN dim_employment e ON b.employment_id = e.employment_id
GROUP BY e.employment_type, e.industry, e.stability_score
ORDER BY default_rate_pct DESC;

-- ----------------------------------------------------------
-- Q12: Vintage Analysis — Default rate by loan cohort month
-- ----------------------------------------------------------
WITH cohort AS (
    SELECT
        dd.year || '-' || LPAD(dd.month_num::TEXT, 2, '0') AS cohort_month,
        fl.loan_id,
        fl.is_default,
        fl.loan_amount
    FROM fact_loans fl
    JOIN dim_date dd ON fl.disbursal_date_id = dd.date_id
)
SELECT
    cohort_month,
    COUNT(*)                                        AS loans_issued,
    COUNT(*) FILTER (WHERE is_default)              AS defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_default) / COUNT(*), 2) AS default_rate_pct,
    ROUND(SUM(loan_amount) / 1e6, 2)                AS disbursed_cr
FROM cohort
GROUP BY cohort_month
ORDER BY cohort_month;

-- ----------------------------------------------------------
-- Q13: Net Charge-Off Rate by quarter
-- ----------------------------------------------------------
SELECT
    dd.year,
    dd.quarter_name,
    COUNT(fl.loan_id)                              AS total_loans,
    COUNT(*) FILTER (WHERE fl.is_default)          AS chargedoff_count,
    ROUND(SUM(fl.charged_off_amount) / 1e6, 2)     AS gross_chargeoff_cr,
    ROUND(SUM(fl.recovery_amount) / 1e6, 2)        AS recovery_cr,
    ROUND((SUM(fl.charged_off_amount) - SUM(fl.recovery_amount)) / 1e6, 2)   AS net_chargeoff_cr,
    ROUND(
        100.0 * (SUM(fl.charged_off_amount) - SUM(fl.recovery_amount))
        / NULLIF(SUM(fl.loan_amount), 0),
        3
    )                                               AS net_chargeoff_rate_pct
FROM fact_loans fl
JOIN dim_date dd ON fl.disbursal_date_id = dd.date_id
GROUP BY dd.year, dd.quarter, dd.quarter_name
ORDER BY dd.year, dd.quarter;

-- ----------------------------------------------------------
-- Q14: Early Warning — Loans with 3+ missed payments
-- ----------------------------------------------------------
WITH payment_flags AS (
    SELECT
        fp.loan_id,
        COUNT(*) FILTER (WHERE fp.payment_status = 'Missed') AS missed_count,
        COUNT(*) FILTER (WHERE fp.payment_status = 'Partial') AS partial_count,
        MAX(fp.days_delay)                                    AS max_delay
    FROM fact_payments fp
    GROUP BY fp.loan_id
)
SELECT
    fl.loan_number,
    b.borrower_name,
    fl.loan_amount,
    fl.loan_status,
    fl.risk_grade,
    pf.missed_count,
    pf.partial_count,
    pf.max_delay,
    CASE
        WHEN pf.missed_count >= 3 OR pf.max_delay >= 90 THEN 'CRITICAL'
        WHEN pf.missed_count >= 2 OR pf.max_delay >= 60 THEN 'WARNING'
        WHEN pf.missed_count >= 1 OR pf.max_delay >= 30 THEN 'WATCH'
        ELSE 'NORMAL'
    END AS early_warning_flag
FROM fact_loans fl
JOIN dim_borrower b    ON fl.borrower_id = b.borrower_id
JOIN payment_flags pf  ON fl.loan_id     = pf.loan_id
WHERE pf.missed_count > 0
ORDER BY pf.missed_count DESC, pf.max_delay DESC;

-- ----------------------------------------------------------
-- Q15: Geographic default heatmap
-- ----------------------------------------------------------
SELECT
    g.city,
    g.state,
    g.region,
    COUNT(fl.loan_id)                              AS total_loans,
    COUNT(*) FILTER (WHERE fl.is_default)          AS defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE fl.is_default) / COUNT(*), 2) AS default_rate_pct,
    ROUND(SUM(fl.loan_amount) / 1e6, 2)            AS portfolio_cr
FROM fact_loans fl
JOIN dim_borrower b   ON fl.borrower_id   = b.borrower_id
JOIN dim_geography g  ON b.geography_id   = g.geography_id
GROUP BY g.city, g.state, g.region
ORDER BY default_rate_pct DESC;
