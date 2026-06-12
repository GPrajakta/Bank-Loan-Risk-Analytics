-- ============================================================
-- Bank Loan Risk Analytics | KPI & Portfolio Summaries
-- ============================================================
SET search_path = loan_risk;

-- ----------------------------------------------------------
-- Q16: Executive Dashboard KPIs (single-row summary)
-- ----------------------------------------------------------
WITH base AS (
    SELECT
        COUNT(*)                                                AS total_loans,
        ROUND(SUM(loan_amount) / 1e7, 2)                        AS total_portfolio_cr,
        ROUND(AVG(loan_amount), 0)                              AS avg_loan_amt,
        ROUND(AVG(interest_rate), 2)                            AS avg_interest_rate,
        ROUND(AVG(credit_score_at_origination), 0)             AS avg_credit_score,
        ROUND(AVG(dti_ratio), 2)                                AS avg_dti,
        COUNT(*) FILTER (WHERE loan_status = 'Current')         AS active_loans,
        COUNT(*) FILTER (WHERE is_default)                      AS total_defaults,
        ROUND(SUM(charged_off_amount) / 1e7, 2)                 AS total_chargeoff_cr,
        ROUND(SUM(recovery_amount) / 1e7, 2)                    AS total_recovery_cr
    FROM fact_loans
)
SELECT
    *,
    ROUND(100.0 * total_defaults / total_loans, 2)              AS default_rate_pct,
    ROUND(100.0 * active_loans / total_loans, 2)                AS active_rate_pct,
    ROUND(100.0 * (total_chargeoff_cr - total_recovery_cr)
          / NULLIF(total_portfolio_cr, 0), 3)                   AS net_chargeoff_rate_pct
FROM base;

-- ----------------------------------------------------------
-- Q17: Rolling 3-month average default rate (window function)
-- ----------------------------------------------------------
WITH monthly_defaults AS (
    SELECT
        dd.year,
        dd.month_num,
        dd.month_name,
        COUNT(fl.loan_id)                              AS issued,
        COUNT(*) FILTER (WHERE fl.is_default)          AS defaults
    FROM fact_loans fl
    JOIN dim_date dd ON fl.disbursal_date_id = dd.date_id
    GROUP BY dd.year, dd.month_num, dd.month_name
)
SELECT
    year,
    month_name,
    issued,
    defaults,
    ROUND(100.0 * defaults / NULLIF(issued, 0), 2)               AS monthly_default_pct,
    ROUND(
        AVG(100.0 * defaults / NULLIF(issued, 0))
        OVER (ORDER BY year, month_num ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    )                                                            AS rolling_3m_default_pct
FROM monthly_defaults
ORDER BY year, month_num;

-- ----------------------------------------------------------
-- Q18: Loan performance funnel (count per stage)
-- ----------------------------------------------------------
SELECT
    status_stage,
    loan_count,
    ROUND(100.0 * loan_count / SUM(loan_count) OVER (), 2) AS pct_of_total
FROM (
    SELECT 'Applied'   AS status_stage, COUNT(*) AS loan_count FROM fact_loans
    UNION ALL
    SELECT 'Approved',  COUNT(*) FROM fact_loans WHERE loan_status <> 'Rejected'
    UNION ALL
    SELECT 'Disbursed', COUNT(*) FROM fact_loans WHERE disbursal_date_id IS NOT NULL
    UNION ALL
    SELECT 'Active',    COUNT(*) FROM fact_loans WHERE loan_status = 'Current'
    UNION ALL
    SELECT 'Closed',    COUNT(*) FROM fact_loans WHERE loan_status = 'Closed'
    UNION ALL
    SELECT 'Default',   COUNT(*) FROM fact_loans WHERE is_default
) funnel
ORDER BY loan_count DESC;

-- ----------------------------------------------------------
-- Q19: Rank borrowers by composite risk using window functions
-- ----------------------------------------------------------
WITH risk_ranked AS (
    SELECT
        b.borrower_name,
        fl.loan_number,
        fl.loan_amount,
        fl.credit_score_at_origination,
        fl.dti_ratio,
        fl.risk_grade,
        fl.is_default,
        DENSE_RANK() OVER (ORDER BY fl.dti_ratio DESC)              AS dti_rank,
        DENSE_RANK() OVER (ORDER BY fl.credit_score_at_origination) AS credit_risk_rank,
        NTILE(5) OVER (ORDER BY fl.loan_amount DESC)                AS loan_size_quintile
    FROM fact_loans fl
    JOIN dim_borrower b ON fl.borrower_id = b.borrower_id
    WHERE fl.loan_status NOT IN ('Closed')
)
SELECT *,
    ROUND((dti_rank + credit_risk_rank) / 2.0, 0) AS combined_rank
FROM risk_ranked
ORDER BY combined_rank
LIMIT 50;

-- ----------------------------------------------------------
-- Q20: Interest income projection vs actual (YoY)
-- ----------------------------------------------------------
SELECT
    dd.year,
    COUNT(fl.loan_id)                              AS loans,
    ROUND(SUM(fl.loan_amount * fl.interest_rate / 100) / 1e6, 2)  AS projected_interest_income_cr,
    ROUND(SUM(fp.interest_component) / 1e6, 2)                    AS actual_collected_cr,
    ROUND(SUM(fp.interest_component) / NULLIF(SUM(fl.loan_amount * fl.interest_rate / 100), 0) * 100, 2) AS collection_efficiency_pct
FROM fact_loans fl
JOIN dim_date dd ON fl.disbursal_date_id = dd.date_id
JOIN fact_payments fp ON fl.loan_id = fp.loan_id
GROUP BY dd.year
ORDER BY dd.year;
