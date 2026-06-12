-- ============================================================
-- File: 02_indexes.sql  — Performance indexes
-- ============================================================

-- Borrowers
CREATE INDEX idx_borrowers_credit_score  ON borrowers(credit_score);
CREATE INDEX idx_borrowers_state         ON borrowers(state);
CREATE INDEX idx_borrowers_employment    ON borrowers(employment_type);

-- Applications
CREATE INDEX idx_applications_borrower   ON loan_applications(borrower_id);
CREATE INDEX idx_applications_product    ON loan_applications(product_id);
CREATE INDEX idx_applications_date       ON loan_applications(application_date);
CREATE INDEX idx_applications_status     ON loan_applications(status);

-- Accounts
CREATE INDEX idx_accounts_borrower       ON loan_accounts(borrower_id);
CREATE INDEX idx_accounts_product        ON loan_accounts(product_id);
CREATE INDEX idx_accounts_branch         ON loan_accounts(branch_id);
CREATE INDEX idx_accounts_status         ON loan_accounts(account_status);
CREATE INDEX idx_accounts_disbursal_date ON loan_accounts(disbursal_date);
CREATE INDEX idx_accounts_npa_date       ON loan_accounts(npa_date);
CREATE INDEX idx_accounts_dpd            ON loan_accounts(dpd_current);

-- Payments
CREATE INDEX idx_payments_account        ON loan_payments(account_id);
CREATE INDEX idx_payments_due_date       ON loan_payments(due_date);
CREATE INDEX idx_payments_paid_date      ON loan_payments(paid_date);
CREATE INDEX idx_payments_status         ON loan_payments(payment_status);

-- Composite — most common dashboard filter
CREATE INDEX idx_accounts_product_status ON loan_accounts(product_id, account_status);
CREATE INDEX idx_payments_account_due    ON loan_payments(account_id, due_date);
