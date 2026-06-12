-- ============================================================
-- Bank Loan Risk Analytics | Stored Procedures & Functions
-- ============================================================
SET search_path = loan_risk;

-- SP1: Refresh Risk Grades
CREATE OR REPLACE PROCEDURE refresh_risk_scores()
LANGUAGE plpgsql AS $$
DECLARE v_updated INT := 0;
BEGIN
    WITH scores AS (
        SELECT
            fl.loan_id,
            ROUND(
                fl.dti_ratio / 55.0 * 30
                + (1 - (fl.credit_score_at_origination - 300.0) / 600) * 40
                + fl.ltv_ratio / 90.0 * 20
                + (10 - e.stability_score) / 9.0 * 10,
            2) AS composite_score
        FROM fact_loans fl
        JOIN dim_borrower b   ON fl.borrower_id  = b.borrower_id
        JOIN dim_employment e ON b.employment_id = e.employment_id
        WHERE fl.loan_status = 'Current'
    )
    UPDATE fact_loans fl
    SET risk_grade = CASE
        WHEN s.composite_score < 20 THEN 'A'
        WHEN s.composite_score < 40 THEN 'B'
        WHEN s.composite_score < 60 THEN 'C'
        WHEN s.composite_score < 80 THEN 'D'
        ELSE 'E'
    END
    FROM scores s WHERE fl.loan_id = s.loan_id;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RAISE NOTICE 'Risk grades refreshed for % loans', v_updated;
END;
$$;

-- SP2: Flag Early Warnings
CREATE OR REPLACE PROCEDURE flag_early_warnings(p_min_missed INT DEFAULT 2)
LANGUAGE plpgsql AS $$
DECLARE v_flagged INT := 0;
BEGIN
    WITH payment_summary AS (
        SELECT loan_id,
            COUNT(*) FILTER (WHERE payment_status = 'Missed') AS missed_count,
            MAX(days_delay) AS max_delay
        FROM fact_payments GROUP BY loan_id
    )
    UPDATE fact_loans fl
    SET
        loan_status   = CASE
            WHEN ps.max_delay >= 90 THEN '90DPD'
            WHEN ps.max_delay >= 60 THEN '60DPD'
            WHEN ps.max_delay >= 30 THEN '30DPD'
            ELSE fl.loan_status END,
        days_past_due = ps.max_delay
    FROM payment_summary ps
    WHERE fl.loan_id = ps.loan_id
      AND fl.loan_status = 'Current'
      AND ps.missed_count >= p_min_missed;
    GET DIAGNOSTICS v_flagged = ROW_COUNT;
    RAISE NOTICE '% loans flagged for early warning', v_flagged;
END;
$$;

-- FUNCTION: Calculate EMI
CREATE OR REPLACE FUNCTION calculate_emi(
    p_principal      NUMERIC,
    p_annual_rate    NUMERIC,
    p_tenure_months  INT
) RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE
    v_monthly_rate NUMERIC;
BEGIN
    IF p_annual_rate = 0 THEN RETURN ROUND(p_principal / p_tenure_months, 2); END IF;
    v_monthly_rate := p_annual_rate / 1200.0;
    RETURN ROUND(
        p_principal * v_monthly_rate
        * POWER(1 + v_monthly_rate, p_tenure_months)
        / (POWER(1 + v_monthly_rate, p_tenure_months) - 1),
    2);
END; $$;

-- FUNCTION: Borrower Risk Summary
CREATE OR REPLACE FUNCTION get_borrower_risk_summary(p_borrower_id INT)
RETURNS TABLE (
    borrower_name TEXT, total_loans BIGINT, active_loans BIGINT,
    total_exposure NUMERIC, default_count BIGINT, max_dpd INT,
    avg_credit_score NUMERIC, risk_flag TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT b.borrower_name::TEXT, COUNT(fl.loan_id),
        COUNT(*) FILTER (WHERE fl.loan_status = 'Current'),
        ROUND(SUM(fl.loan_amount)/1e5, 2),
        COUNT(*) FILTER (WHERE fl.is_default),
        MAX(fl.days_past_due),
        ROUND(AVG(fl.credit_score_at_origination)::NUMERIC, 0),
        CASE
            WHEN COUNT(*) FILTER (WHERE fl.is_default) > 0 THEN 'HIGH RISK'
            WHEN MAX(fl.days_past_due) >= 30              THEN 'WATCH'
            ELSE 'NORMAL' END
    FROM fact_loans fl
    JOIN dim_borrower b ON fl.borrower_id = b.borrower_id
    WHERE b.borrower_id = p_borrower_id
    GROUP BY b.borrower_name;
END; $$;
