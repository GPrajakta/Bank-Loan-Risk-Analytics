#!/bin/bash
# ============================================================
# Bank Loan Risk Analytics — One-shot DB setup
# Usage: bash scripts/setup.sh [dbname] [user]
# ============================================================
set -e

DB_NAME=${1:-loan_risk_db}
DB_USER=${2:-postgres}

echo "========================================"
echo " Bank Loan Risk Analytics - Setup"
echo " DB: $DB_NAME | User: $DB_USER"
echo "========================================"

# Create DB
psql -U "$DB_USER" -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 \
  || psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"

echo "[1/4] Running schema..."
psql -U "$DB_USER" -d "$DB_NAME" -f sql/schema/01_create_tables.sql

echo "[2/4] Loading seed data..."
psql -U "$DB_USER" -d "$DB_NAME" -f data/sample_data/seed_data.sql

echo "[3/4] Creating views..."
psql -U "$DB_USER" -d "$DB_NAME" -f sql/views/06_analytical_views.sql

echo "[4/4] Creating stored procedures..."
psql -U "$DB_USER" -d "$DB_NAME" -f sql/stored_procedures/07_stored_procedures.sql

echo ""
echo "✅ Setup complete! Database '$DB_NAME' is ready."
echo ""
echo "To connect in Power BI:"
echo "  Server: localhost | Database: $DB_NAME"
echo "  Views to import: vw_loan_summary, vw_risk_segments, vw_monthly_trends, vw_borrower_profile"
