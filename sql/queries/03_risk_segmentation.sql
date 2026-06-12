-- ============================================================
-- Bank Loan Risk Analytics | Risk Segmentation Queries
-- ============================================================
SET search_path = loan_risk;

-- ----------------------------------------------------------
-- Q7: Composite Risk Score (0-100) per loan
--     DTI (30%) + Credit Score (40%) + LTV (20%) + Employment (10%)
-- ----------------------------------------------------------
WITH risk_scores AS (
    SELECT
        fl.loan_id,
        fl.loan_number,
        fl.loan_amount,
        fl.loan_status,
        fl.dti_ratio,
        fl.ltv_ratio,
        fl.credit_score_at_origination,
        e.stability_score,

        -- Normalize each component (higher = more risk)
        ROUND(fl.dti_ratio / 55.0 * 30, 2)                              AS dti_score,     -- max DTI ~55%
        ROUND((1 - (fl.credit_score_at_origination - 300.0) / 600) * 40, 2) AS credit_score_risk,
        ROUND(fl.ltv_ratio / 90.0 * 20, 2)                              AS ltv_score,     -- max LTV ~90%
        ROUND((10 - e.stability_score) / 9.0 * 10, 2)                   AS emp_risk_score
    FROM fact_loans fl
    JOIN dim_borrower b   ON fl.borrower_id = b.borrower_id
    JOIN dim_employment e ON b.employment_id = e.employment_id
)
SELECT
    loan_id,
    loan_number,
    loan_amount,
    loan_status,
    dti_ratio,
    credit_score_at_origination,
    ROUND(dti_score + credit_score_risk + ltv_score + emp_risk_score, 2) AS composite_risk_score,
    CASE
        WHEN (dti_score + credit_score_risk + ltv_score + emp_risk_score) < 25  THEN 'Low Risk'
        WHEN (dti_score + credit_score_risk + ltv_score + emp_risk_score) < 50  THEN 'Medium Risk'
        WHEN (dti_score + credit_score_risk + ltv_score + emp_risk_score) < 75  THEN 'High Risk'
        ELSE 'Very High Risk'
    END AS risk_segment
FROM risk_scores
ORDER BY composite_risk_score DESC;

-- ----------------------------------------------------------
-- Q8: Risk band summary — count, default rate, exposure
-- ----------------------------------------------------------
WITH risk_scores AS (
    SELECT
        fl.loan_id,
        fl.loan_amount,
        fl.is_default,
        ROUND(
            fl.dti_ratio / 55.0 * 30
            + (1 - (fl.credit_score_at_origination - 300.0) / 600) * 40
            + fl.ltv_ratio / 90.0 * 20
            + (10 - e.stability_score) / 9.0 * 10,
        2) AS composite_risk_score
    FROM fact_loans fl
    JOIN dim_borrower b   ON fl.borrower_id  = b.borrower_id
    JOIN dim_employment e ON b.employment_id = e.employment_id
),
banded AS (
    SELECT *,
        CASE
            WHEN composite_risk_score < 25 THEN 'Low Risk'
            WHEN composite_risk_score < 50 THEN 'Medium Risk'
            WHEN composite_risk_score < 75 THEN 'High Risk'
            ELSE 'Very High Risk'
        END AS risk_segment
    FROM risk_scores
)
SELECT
    risk_segment,
    COUNT(*)                                           AS loan_count,
    ROUND(SUM(loan_amount) / 1e6, 2)                   AS exposure_cr,
    COUNT(*) FILTER (WHERE is_default)                 AS defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_default) / COUNT(*), 2) AS default_rate_pct
FROM banded
GROUP BY risk_segment
ORDER BY MIN(composite_risk_score);

-- ----------------------------------------------------------
-- Q9: DTI vs Credit Score scatter data (for Power BI)
-- ----------------------------------------------------------
SELECT
    fl.loan_id,
    fl.dti_ratio,
    fl.credit_score_at_origination,
    fl.loan_amount,
    fl.interest_rate,
    fl.is_default,
    fl.risk_grade,
    lp.purpose_name,
    e.employment_type
FROM fact_loans fl
JOIN dim_borrower b     ON fl.borrower_id  = b.borrower_id
JOIN dim_employment e   ON b.employment_id = e.employment_id
JOIN dim_loan_purpose lp ON fl.purpose_id  = lp.purpose_id
WHERE fl.loan_status NOT IN ('Closed');

-- ----------------------------------------------------------
-- Q10: Portfolio at Risk (PAR) — 30 / 60 / 90 DPD
-- ----------------------------------------------------------
SELECT
    'PAR 30' AS par_bucket,
    COUNT(*)                             AS loan_count,
    ROUND(SUM(loan_amount) / 1e6, 2)     AS outstanding_cr,
    ROUND(100.0 * SUM(loan_amount) / (SELECT SUM(loan_amount) FROM fact_loans), 2) AS pct_of_portfolio
FROM fact_loans
WHERE loan_status IN ('30DPD','60DPD','90DPD','Default','NPA')

UNION ALL

SELECT 'PAR 60',
    COUNT(*), ROUND(SUM(loan_amount)/1e6,2),
    ROUND(100.0 * SUM(loan_amount) / (SELECT SUM(loan_amount) FROM fact_loans), 2)
FROM fact_loans
WHERE loan_status IN ('60DPD','90DPD','Default','NPA')

UNION ALL

SELECT 'PAR 90',
    COUNT(*), ROUND(SUM(loan_amount)/1e6,2),
    ROUND(100.0 * SUM(loan_amount) / (SELECT SUM(loan_amount) FROM fact_loans), 2)
FROM fact_loans
WHERE loan_status IN ('90DPD','Default','NPA');
