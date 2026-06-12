# Power BI DAX Measures — Bank Loan Risk Analytics
> Paste each measure into the Power BI model via **Modeling → New Measure**
> Table prefix: `vw_loan_summary` is the main table

---

## 📌 1. Base KPI Measures

### Total Loans
```dax
Total Loans = COUNTROWS(vw_loan_summary)
```

### Total Portfolio Value (Cr)
```dax
Total Portfolio Cr =
DIVIDE(SUM(vw_loan_summary[loan_amount]), 1e7, 0)
```

### Active Loans
```dax
Active Loans =
CALCULATE(
    COUNTROWS(vw_loan_summary),
    vw_loan_summary[loan_status] = "Current"
)
```

### Total Defaults
```dax
Total Defaults =
CALCULATE(
    COUNTROWS(vw_loan_summary),
    vw_loan_summary[is_default] = TRUE()
)
```

### Default Rate %
```dax
Default Rate % =
DIVIDE([Total Defaults], [Total Loans], 0) * 100
```

### Average Interest Rate
```dax
Avg Interest Rate =
AVERAGE(vw_loan_summary[interest_rate])
```

### Average Credit Score
```dax
Avg Credit Score =
AVERAGE(vw_loan_summary[credit_score_at_origination])
```

### Average DTI
```dax
Avg DTI =
AVERAGE(vw_loan_summary[dti_ratio])
```

---

## 📌 2. Portfolio at Risk (PAR)

### PAR 30 Amount (Cr)
```dax
PAR 30 Amount Cr =
CALCULATE(
    DIVIDE(SUM(vw_loan_summary[loan_amount]), 1e7),
    vw_loan_summary[loan_status] IN {"30DPD","60DPD","90DPD","Default","NPA"}
)
```

### PAR 60 Amount (Cr)
```dax
PAR 60 Amount Cr =
CALCULATE(
    DIVIDE(SUM(vw_loan_summary[loan_amount]), 1e7),
    vw_loan_summary[loan_status] IN {"60DPD","90DPD","Default","NPA"}
)
```

### PAR 90 Amount (Cr)
```dax
PAR 90 Amount Cr =
CALCULATE(
    DIVIDE(SUM(vw_loan_summary[loan_amount]), 1e7),
    vw_loan_summary[loan_status] IN {"90DPD","Default","NPA"}
)
```

### PAR 30 % of Portfolio
```dax
PAR 30 % =
DIVIDE([PAR 30 Amount Cr], [Total Portfolio Cr], 0) * 100
```

---

## 📌 3. Charge-Off & Recovery

### Total Charged Off (Cr)
```dax
Total Chargeoff Cr =
DIVIDE(SUM(vw_loan_summary[charged_off_amount]), 1e7, 0)
```

### Total Recovery (Cr)
```dax
Total Recovery Cr =
DIVIDE(SUM(vw_loan_summary[recovery_amount]), 1e7, 0)
```

### Net Charge-Off (Cr)
```dax
Net Chargeoff Cr = [Total Chargeoff Cr] - [Total Recovery Cr]
```

### Net Charge-Off Rate %
```dax
Net Chargeoff Rate % =
DIVIDE([Net Chargeoff Cr], [Total Portfolio Cr], 0) * 100
```

### Recovery Rate %
```dax
Recovery Rate % =
DIVIDE([Total Recovery Cr], [Total Chargeoff Cr], 0) * 100
```

---

## 📌 4. Time Intelligence Measures

### Loans YTD
```dax
Loans YTD =
CALCULATE(
    [Total Loans],
    DATESYTD(dim_date[full_date])
)
```

### Portfolio YoY Growth %
```dax
Portfolio YoY Growth % =
VAR CurrentYear  = [Total Portfolio Cr]
VAR PreviousYear = CALCULATE(
    [Total Portfolio Cr],
    SAMEPERIODLASTYEAR(dim_date[full_date])
)
RETURN
DIVIDE(CurrentYear - PreviousYear, PreviousYear, 0) * 100
```

### Default Rate MoM Change
```dax
Default Rate MoM Change =
VAR CurrentMonth  = [Default Rate %]
VAR PreviousMonth = CALCULATE(
    [Default Rate %],
    DATEADD(dim_date[full_date], -1, MONTH)
)
RETURN CurrentMonth - PreviousMonth
```

### Rolling 3-Month Default Rate
```dax
Rolling 3M Default Rate =
CALCULATE(
    [Default Rate %],
    DATESINPERIOD(
        dim_date[full_date],
        LASTDATE(dim_date[full_date]),
        -3, MONTH
    )
)
```

### Cumulative Portfolio (Running Total)
```dax
Cumulative Portfolio Cr =
CALCULATE(
    [Total Portfolio Cr],
    FILTER(
        ALLSELECTED(dim_date[full_date]),
        dim_date[full_date] <= MAX(dim_date[full_date])
    )
)
```

---

## 📌 5. Risk Segmentation Measures

### High Risk Loan Count
```dax
High Risk Loans =
CALCULATE(
    COUNTROWS(vw_risk_segments),
    vw_risk_segments[risk_segment] IN {"High Risk","Very High Risk"}
)
```

### High Risk % of Portfolio
```dax
High Risk % =
DIVIDE(
    [High Risk Loans],
    CALCULATE(COUNTROWS(vw_risk_segments), ALL(vw_risk_segments[risk_segment])),
    0
) * 100
```

### Avg Composite Risk Score
```dax
Avg Risk Score =
AVERAGE(vw_risk_segments[composite_risk_score])
```

### Risk Grade Distribution (for Donut Chart)
```dax
Grade A Loans = CALCULATE([Total Loans], vw_loan_summary[risk_grade] = "A")
Grade B Loans = CALCULATE([Total Loans], vw_loan_summary[risk_grade] = "B")
Grade C Loans = CALCULATE([Total Loans], vw_loan_summary[risk_grade] = "C")
Grade D Loans = CALCULATE([Total Loans], vw_loan_summary[risk_grade] = "D")
Grade E Loans = CALCULATE([Total Loans], vw_loan_summary[risk_grade] = "E")
```

---

## 📌 6. Calculated Columns (Add to vw_loan_summary)

### Credit Score Band
```dax
Credit Score Band =
SWITCH(
    TRUE(),
    vw_loan_summary[credit_score_at_origination] < 580,  "< 580 Poor",
    vw_loan_summary[credit_score_at_origination] < 670,  "580–669 Fair",
    vw_loan_summary[credit_score_at_origination] < 740,  "670–739 Good",
    vw_loan_summary[credit_score_at_origination] < 800,  "740–799 Very Good",
    "800+ Excellent"
)
```

### Income Band
```dax
Income Band =
SWITCH(
    TRUE(),
    vw_loan_summary[annual_income] < 300000,  "< 3L",
    vw_loan_summary[annual_income] < 600000,  "3L–6L",
    vw_loan_summary[annual_income] < 1200000, "6L–12L",
    vw_loan_summary[annual_income] < 2500000, "12L–25L",
    "> 25L"
)
```

### Loan Size Category
```dax
Loan Size Category =
SWITCH(
    TRUE(),
    vw_loan_summary[loan_amount] < 100000,  "< 1L (Micro)",
    vw_loan_summary[loan_amount] < 500000,  "1L–5L (Small)",
    vw_loan_summary[loan_amount] < 2000000, "5L–20L (Medium)",
    vw_loan_summary[loan_amount] < 5000000, "20L–50L (Large)",
    "> 50L (Very Large)"
)
```

### DTI Risk Flag
```dax
DTI Risk Flag =
IF(
    vw_loan_summary[dti_ratio] > 40,
    "High DTI",
    IF(vw_loan_summary[dti_ratio] > 25, "Moderate DTI", "Healthy DTI")
)
```

### EMI Burden %
```dax
EMI Burden % =
DIVIDE(
    vw_loan_summary[emi_amount] * 12,
    vw_loan_summary[annual_income],
    0
) * 100
```

---

## 📌 7. Advanced Measures

### Weighted Average Interest Rate
```dax
Weighted Avg Rate =
DIVIDE(
    SUMX(vw_loan_summary, vw_loan_summary[loan_amount] * vw_loan_summary[interest_rate]),
    SUM(vw_loan_summary[loan_amount]),
    0
)
```

### Expected Loss (Simplified)
```dax
Expected Loss Cr =
DIVIDE(
    SUMX(
        vw_risk_segments,
        vw_risk_segments[loan_amount]
            * vw_risk_segments[composite_risk_score] / 100
            * 0.45   -- assumed Loss Given Default (LGD) = 45%
    ),
    1e7,
    0
)
```

### Concentration Risk (Herfindahl Index by Purpose)
```dax
HHI Concentration =
VAR TotalLoans = [Total Loans]
RETURN
SUMX(
    VALUES(vw_loan_summary[purpose_name]),
    POWER(
        DIVIDE(
            CALCULATE(COUNTROWS(vw_loan_summary)),
            TotalLoans,
            0
        ),
        2
    )
)
-- HHI > 0.25 = high concentration; < 0.10 = diversified
```

### Dynamic KPI Card Title
```dax
KPI Subtitle =
"As of " & FORMAT(TODAY(), "MMM YYYY") &
" | Portfolio: ₹" & FORMAT([Total Portfolio Cr], "#,##0.0") & " Cr"
```

---

## 📌 8. Slicer / Filter Measures

### Selected Risk Grade Label
```dax
Selected Grade =
IF(
    ISFILTERED(vw_loan_summary[risk_grade]),
    "Grade: " & SELECTEDVALUE(vw_loan_summary[risk_grade], "Multiple"),
    "All Grades"
)
```

### Filtered Default Rate (respects slicers)
```dax
Filtered Default Rate % =
DIVIDE(
    CALCULATE([Total Defaults]),
    CALCULATE([Total Loans]),
    0
) * 100
```
