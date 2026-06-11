# 🏦 Bank Loan Risk Analytics

> End-to-end loan risk intelligence platform built on **PostgreSQL + Power BI**

A production-grade analytics solution that models loan portfolio risk, tracks default patterns, and delivers executive-level KPIs using structured SQL pipelines and Power BI DAX measures.

---

## 📁 Project Structure

```
bank-loan-risk-analytics/
├── sql/
│   ├── schema/         01_create_tables.sql
│   ├── queries/        02_exploratory_analysis.sql
│   │                   03_risk_segmentation.sql
│   │                   04_default_analysis.sql
│   │                   05_portfolio_summary.sql
│   ├── views/          06_analytical_views.sql
│   └── stored_procedures/ 07_stored_procedures.sql
├── powerbi/dax/        08_dax_measures.md
├── data/sample_data/   seed_data.sql
├── scripts/            setup.sh
├── docs/               data_dictionary.md
└── README.md
```

---

## 🧱 Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Storage | PostgreSQL 15+ | Source of truth |
| Transformation | SQL (CTEs, Window Functions) | Risk calculation, aggregation |
| Visualization | Power BI Desktop | Dashboards, KPI reports |
| Modeling | DAX | Calculated measures, time-intelligence |

---

## 🚀 Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/bank-loan-risk-analytics.git
cd bank-loan-risk-analytics
bash scripts/setup.sh
```

Then in Power BI Desktop:
1. Get Data → PostgreSQL → localhost → loan_risk_db
2. Import views: vw_loan_summary, vw_risk_segments, vw_monthly_trends, vw_borrower_profile
3. Apply DAX measures from powerbi/dax/08_dax_measures.md

---

## 📊 Dashboard Pages

| Page | Description |
|---|---|
| Executive Overview | Portfolio value, default rate, approval rate |
| Risk Segmentation | Risk band distribution, DTI vs credit score |
| Default Analysis | Default by purpose, employment, geography |
| Vintage Analysis | Cohort-based default curves over time |
| Borrower Profile | Income distribution, loan purpose breakdown |

---

## 📐 Data Model (Star Schema)

dim_borrower, dim_loan_purpose, dim_date, dim_employment, dim_geography
→ fact_loans ← fact_payments

---

## 👤 Author

**Prajakta Gitte** — Data Analyst
Skills: SQL · Power BI · Python · DAX
