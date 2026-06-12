# Data Dictionary — Bank Loan Risk Analytics

## fact_loans

| Column | Type | Description | Example |
|---|---|---|---|
| loan_id | SERIAL PK | Surrogate key | 1, 2, 3 |
| loan_number | VARCHAR(20) | Human-readable ID | LN-00001 |
| borrower_id | INT FK | Links to dim_borrower | 5 |
| purpose_id | INT FK | Links to dim_loan_purpose | 3 |
| loan_amount | NUMERIC | Disbursed amount in ₹ | 500000 |
| interest_rate | NUMERIC | Annual interest rate % | 12.5 |
| tenure_months | INT | Loan duration in months | 60 |
| emi_amount | NUMERIC | Monthly EMI in ₹ | 11249 |
| credit_score_at_origination | INT | CIBIL score at time of loan | 720 |
| dti_ratio | NUMERIC | Debt-to-Income % | 28.5 |
| ltv_ratio | NUMERIC | Loan-to-Value % | 75.0 |
| loan_status | VARCHAR | Current loan state | Current |
| is_default | BOOLEAN | Computed: status IN (Default, NPA) | false |
| days_past_due | INT | Max days overdue | 0 |
| charged_off_amount | NUMERIC | Amount written off | 0 |
| recovery_amount | NUMERIC | Amount recovered post-default | 0 |
| risk_grade | VARCHAR(5) | A (best) to E (worst) | B |

## Loan Status Values

| Status | Meaning |
|---|---|
| Current | Performing, payments up to date |
| Closed | Fully repaid |
| 30DPD | 30–59 days past due |
| 60DPD | 60–89 days past due |
| 90DPD | 90+ days past due, pre-NPA |
| Default | Formally declared defaulted |
| NPA | Non-Performing Asset (RBI classification) |

## Risk Grade Logic

| Grade | Composite Score | Profile |
|---|---|---|
| A | 0–20 | Excellent — low DTI, high credit score, stable employment |
| B | 21–40 | Good — minor risk factors |
| C | 41–60 | Moderate — watch closely |
| D | 61–80 | High risk — elevated DTI or poor credit |
| E | 81–100 | Very high risk — multiple risk factors |

## Composite Risk Score Formula

```
Score = (DTI / 55) × 30
      + (1 − (CreditScore − 300) / 600) × 40
      + (LTV / 90) × 20
      + (10 − EmploymentStability) / 9 × 10
```

Weights: DTI=30%, Credit Score=40%, LTV=20%, Employment=10%

## Key Business KPIs

| KPI | Formula |
|---|---|
| Default Rate | Defaults / Total Loans × 100 |
| Net Charge-Off Rate | (Charged Off − Recovery) / Portfolio × 100 |
| PAR 30 | Outstanding balance of loans 30+ DPD |
| EMI Burden % | (EMI × 12) / Annual Income × 100 |
| Collection Efficiency | Amount Collected / Amount Scheduled × 100 |
