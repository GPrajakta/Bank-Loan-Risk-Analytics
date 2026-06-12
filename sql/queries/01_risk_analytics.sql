-- ============================================================
-- BANK LOAN RISK ANALYTICS — Core Analytical Queries
-- File: queries/01_risk_analytics.sql
-- ============================================================

-- ─────────────────────────────────────────
-- Q1: PORTFOLIO KPI SUMMARY
--     Used on Executive Summary dashboard page
-- ─────────────────────────────────────────
SELECT
    COUNT(*)                                             AS total_loan_accounts,
    SUM(principal_amount)                                AS total_disbursed,
    SUM(outstanding_balance)                             AS total_outstanding,
    SUM(CASE WHEN account_status = 'NPA'       THEN 1 ELSE 0 END) AS npa_count,
    SUM(CASE WHEN account_status = 'NPA'       THEN outstanding_balance ELSE 0 END) AS npa_outstanding,
    SUM(CASE WHEN account_status = 'Active'    THEN 1 ELSE 0 END) AS active_count,
    SUM(CASE WHEN account_status = 'Closed'    THEN 1 ELSE 0 END) AS closed_count,
    SUM(CASE WHEN account_status = 'Written Off' THEN 1 ELSE 0 END) AS written_off_count,
    ROUND(
        100.0 * SUM(CASE WHEN account_status = 'NPA' THEN outstanding_balance ELSE 0 END)
              / NULLIF(SUM(outstanding_balance), 0), 2
    ) AS npl_ratio_pct,
    ROUND(AVG(interest_rate), 2)                        AS avg_interest_rate,
    ROUND(AVG(ltv_ratio), 2)                            AS avg_ltv_ratio
FROM loan_accounts;


-- ─────────────────────────────────────────
-- Q2: DEFAULT RATE BY LOAN PRODUCT TYPE
-- ─────────────────────────────────────────
SELECT
    lp.product_type,
    lp.product_name,
    COUNT(la.account_id)                                            AS total_accounts,
    SUM(la.principal_amount)                                        AS total_disbursed,
    SUM(CASE WHEN la.account_status IN ('NPA','Written Off') THEN 1 ELSE 0 END) AS defaults,
    ROUND(
        100.0 * SUM(CASE WHEN la.account_status IN ('NPA','Written Off') THEN 1 ELSE 0 END)
              / NULLIF(COUNT(la.account_id), 0), 2
    )                                                               AS default_rate_pct,
    ROUND(AVG(la.interest_rate), 2)                                 AS avg_rate
FROM loan_accounts   la
JOIN loan_products   lp ON lp.product_id = la.product_id
GROUP BY lp.product_type, lp.product_name
ORDER BY default_rate_pct DESC;


-- ─────────────────────────────────────────
-- Q3: RISK TIER DISTRIBUTION
-- ─────────────────────────────────────────
SELECT
    rt.tier_code,
    rt.tier_name,
    COUNT(la.account_id)                                     AS loan_count,
    SUM(la.principal_amount)                                 AS total_principal,
    ROUND(AVG(b.credit_score))                               AS avg_credit_score,
    ROUND(
        100.0 * COUNT(la.account_id) / SUM(COUNT(la.account_id)) OVER (), 2
    )                                                        AS portfolio_share_pct,
    SUM(CASE WHEN la.account_status IN ('NPA','Written Off')
             THEN la.outstanding_balance ELSE 0 END)         AS npa_exposure
FROM loan_accounts   la
JOIN risk_tiers      rt ON rt.tier_id  = la.tier_id
JOIN borrowers        b ON  b.borrower_id = la.borrower_id
GROUP BY rt.tier_id, rt.tier_code, rt.tier_name
ORDER BY rt.tier_id;


-- ─────────────────────────────────────────
-- Q4: MONTHLY COLLECTION EFFICIENCY
--     EMI collection rate by month
-- ─────────────────────────────────────────
SELECT
    DATE_TRUNC('month', lp.due_date)::DATE   AS emi_month,
    COUNT(lp.payment_id)                     AS total_emis_due,
    SUM(lp.emi_due)                          AS total_amount_due,
    SUM(lp.amount_paid)                      AS total_collected,
    SUM(CASE WHEN lp.payment_status = 'Paid'    THEN 1 ELSE 0 END) AS fully_paid,
    SUM(CASE WHEN lp.payment_status = 'Partial' THEN 1 ELSE 0 END) AS partially_paid,
    SUM(CASE WHEN lp.payment_status = 'Overdue' THEN 1 ELSE 0 END) AS overdue,
    ROUND(100.0 * SUM(lp.amount_paid) / NULLIF(SUM(lp.emi_due), 0), 2) AS collection_rate_pct
FROM loan_payments lp
GROUP BY DATE_TRUNC('month', lp.due_date)
ORDER BY emi_month;


-- ─────────────────────────────────────────
-- Q5: DELINQUENCY BUCKET AGING
--     DPD buckets for active portfolio
-- ─────────────────────────────────────────
SELECT
    CASE
        WHEN la.dpd_current = 0              THEN '0 - Current'
        WHEN la.dpd_current BETWEEN 1  AND 30 THEN '1-30 DPD'
        WHEN la.dpd_current BETWEEN 31 AND 60 THEN '31-60 DPD'
        WHEN la.dpd_current BETWEEN 61 AND 90 THEN '61-90 DPD'
        WHEN la.dpd_current > 90              THEN '90+ DPD (NPA)'
    END                                                       AS dpd_bucket,
    COUNT(la.account_id)                                      AS loan_count,
    SUM(la.outstanding_balance)                               AS outstanding_exposure,
    ROUND(
        100.0 * SUM(la.outstanding_balance)
              / SUM(SUM(la.outstanding_balance)) OVER (), 2
    )                                                         AS exposure_share_pct
FROM loan_accounts la
WHERE la.account_status NOT IN ('Closed', 'Written Off')
GROUP BY 1
ORDER BY MIN(la.dpd_current);


-- ─────────────────────────────────────────
-- Q6: VINTAGE ANALYSIS (COHORT DEFAULT RATE)
--     Default rate by loan disbursal month
-- ─────────────────────────────────────────
WITH cohort AS (
    SELECT
        DATE_TRUNC('month', disbursal_date)::DATE     AS cohort_month,
        COUNT(account_id)                              AS disbursed_count,
        SUM(principal_amount)                          AS disbursed_amount
    FROM loan_accounts
    GROUP BY 1
),
defaults AS (
    SELECT
        DATE_TRUNC('month', disbursal_date)::DATE     AS cohort_month,
        COUNT(account_id)                              AS default_count,
        SUM(principal_amount)                          AS default_amount
    FROM loan_accounts
    WHERE account_status IN ('NPA', 'Written Off')
    GROUP BY 1
)
SELECT
    c.cohort_month,
    c.disbursed_count,
    c.disbursed_amount,
    COALESCE(d.default_count, 0)                            AS default_count,
    ROUND(
        100.0 * COALESCE(d.default_count, 0) / NULLIF(c.disbursed_count, 0), 2
    )                                                       AS default_rate_pct,
    ROUND(
        100.0 * COALESCE(d.default_amount, 0) / NULLIF(c.disbursed_amount, 0), 2
    )                                                       AS default_amount_rate_pct
FROM cohort   c
LEFT JOIN defaults d ON d.cohort_month = c.cohort_month
ORDER BY c.cohort_month;


-- ─────────────────────────────────────────
-- Q7: BORROWER INCOME vs. DEFAULT ANALYSIS
-- ─────────────────────────────────────────
SELECT
    CASE
        WHEN b.annual_income < 300000                THEN 'Below 3L'
        WHEN b.annual_income BETWEEN 300000 AND 600000  THEN '3L - 6L'
        WHEN b.annual_income BETWEEN 600001 AND 1000000 THEN '6L - 10L'
        WHEN b.annual_income BETWEEN 1000001 AND 2000000 THEN '10L - 20L'
        ELSE 'Above 20L'
    END                                                   AS income_band,
    b.employment_type,
    COUNT(la.account_id)                                  AS loan_count,
    ROUND(AVG(b.credit_score))                            AS avg_credit_score,
    ROUND(AVG(la.interest_rate), 2)                       AS avg_rate,
    SUM(CASE WHEN la.account_status IN ('NPA','Written Off')
             THEN 1 ELSE 0 END)                           AS defaults,
    ROUND(
        100.0 * SUM(CASE WHEN la.account_status IN ('NPA','Written Off')
                         THEN 1 ELSE 0 END)
              / NULLIF(COUNT(la.account_id), 0), 2
    )                                                     AS default_rate_pct
FROM loan_accounts la
JOIN borrowers     b ON b.borrower_id = la.borrower_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- ─────────────────────────────────────────
-- Q8: BRANCH-WISE NPA PERFORMANCE
-- ─────────────────────────────────────────
SELECT
    br.region,
    br.state,
    br.branch_name,
    COUNT(la.account_id)                                           AS total_accounts,
    SUM(la.principal_amount)                                       AS total_disbursed,
    SUM(la.outstanding_balance)                                    AS total_outstanding,
    SUM(CASE WHEN la.account_status = 'NPA'
             THEN la.outstanding_balance ELSE 0 END)               AS npa_amount,
    ROUND(
        100.0 * SUM(CASE WHEN la.account_status = 'NPA'
                         THEN la.outstanding_balance ELSE 0 END)
              / NULLIF(SUM(la.outstanding_balance), 0), 2
    )                                                              AS npa_ratio_pct,
    ROUND(AVG(la.dpd_current), 1)                                  AS avg_dpd
FROM loan_accounts la
JOIN branches      br ON br.branch_id = la.branch_id
GROUP BY br.region, br.state, br.branch_name
ORDER BY npa_ratio_pct DESC;


-- ─────────────────────────────────────────
-- Q9: CREDIT SCORE BAND × LOAN PRODUCT
--     Cross-tab heatmap data
-- ─────────────────────────────────────────
SELECT
    CASE
        WHEN b.credit_score BETWEEN 300 AND 549  THEN '300-549'
        WHEN b.credit_score BETWEEN 550 AND 649  THEN '550-649'
        WHEN b.credit_score BETWEEN 650 AND 699  THEN '650-699'
        WHEN b.credit_score BETWEEN 700 AND 749  THEN '700-749'
        WHEN b.credit_score BETWEEN 750 AND 799  THEN '750-799'
        WHEN b.credit_score BETWEEN 800 AND 900  THEN '800-900'
    END                                                     AS score_band,
    lp.product_type,
    COUNT(la.account_id)                                    AS loan_count,
    ROUND(AVG(la.interest_rate), 2)                         AS avg_rate,
    ROUND(
        100.0 * SUM(CASE WHEN la.account_status IN ('NPA','Written Off')
                         THEN 1 ELSE 0 END)
              / NULLIF(COUNT(*), 0), 2
    )                                                       AS default_rate_pct
FROM loan_accounts  la
JOIN borrowers       b  ON b.borrower_id  = la.borrower_id
JOIN loan_products  lp  ON lp.product_id  = la.product_id
GROUP BY 1, 2
ORDER BY 1, 2;


-- ─────────────────────────────────────────
-- Q10: REPAYMENT TREND — ROLLING 3-MONTH
--      Moving average collection rate
-- ─────────────────────────────────────────
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', due_date)::DATE             AS month,
        SUM(emi_due)                                    AS due,
        SUM(amount_paid)                                AS collected
    FROM loan_payments
    GROUP BY 1
)
SELECT
    month,
    due,
    collected,
    ROUND(100.0 * collected / NULLIF(due, 0), 2)         AS collection_rate_pct,
    ROUND(AVG(100.0 * collected / NULLIF(due, 0))
          OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)
                                                        AS rolling_3m_avg_pct
FROM monthly
ORDER BY month;


-- ─────────────────────────────────────────
-- Q11: EXPECTED CREDIT LOSS (ECL) ESTIMATE
--      Simplified IFRS 9 stage approach
-- ─────────────────────────────────────────
WITH ecl_base AS (
    SELECT
        la.account_id,
        la.account_no,
        la.outstanding_balance,
        la.dpd_current,
        la.account_status,
        -- Stage classification
        CASE
            WHEN la.dpd_current = 0                              THEN 'Stage 1'
            WHEN la.dpd_current BETWEEN 1 AND 90                 THEN 'Stage 2'
            WHEN la.dpd_current > 90 OR la.account_status = 'NPA' THEN 'Stage 3'
        END AS ecl_stage,
        -- PD (Probability of Default) — simplified lookup
        CASE
            WHEN la.dpd_current = 0                              THEN 0.02
            WHEN la.dpd_current BETWEEN 1 AND 30                  THEN 0.08
            WHEN la.dpd_current BETWEEN 31 AND 60                 THEN 0.20
            WHEN la.dpd_current BETWEEN 61 AND 90                 THEN 0.45
            ELSE 0.80
        END AS pd,
        -- LGD (Loss Given Default) by product
        CASE WHEN lp.is_secured THEN 0.35 ELSE 0.65 END AS lgd,
        la.outstanding_balance                           AS ead  -- Exposure at Default
    FROM loan_accounts la
    JOIN loan_products lp ON lp.product_id = la.product_id
    WHERE la.account_status NOT IN ('Closed', 'Written Off')
)
SELECT
    ecl_stage,
    COUNT(*)                                              AS account_count,
    ROUND(SUM(outstanding_balance))                       AS total_exposure,
    ROUND(AVG(pd) * 100, 1)                               AS avg_pd_pct,
    ROUND(AVG(lgd) * 100, 1)                              AS avg_lgd_pct,
    ROUND(SUM(pd * lgd * ead))                            AS estimated_ecl,
    ROUND(100.0 * SUM(pd * lgd * ead)
                / NULLIF(SUM(ead), 0), 2)                 AS ecl_coverage_pct
FROM ecl_base
GROUP BY ecl_stage
ORDER BY ecl_stage;
