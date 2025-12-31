# E-Commerce Analytics Platform

A production-ready dbt project for e-commerce analytics, demonstrating data modeling expertise, dbt best practices, SQL proficiency, and analytics engineering skills.

## Table of Contents

- [System Design](#system-design)
- [Data Architecture](#data-architecture)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Data Models](#data-models)
- [Incremental Models](#incremental-models)
- [Testing Strategy](#testing-strategy)
- [Performance Considerations](#performance-considerations)
- [Advanced Features](#advanced-features)
- [Sample Query Outputs](#sample-query-outputs)
- [Design Decisions](#design-decisions)
- [Assumptions](#assumptions)
- [Additional Documentation](#additional-documentation)

---

## System Design

### High-Level Data Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            DATA PIPELINE OVERVIEW                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │   SOURCES    │───▶│   STAGING    │───▶│ INTERMEDIATE │───▶│    MARTS      │  │
│  │  (CSV Seeds) │    │   (stg_*)    │    │   (int_*)    │    │  (dim_/fct_)  │  │
│  └──────────────┘    └──────────────┘    └──────────────┘    └───────────────┘  │
│                                                                                 │
│  • raw_users         • stg_users         • int_orders_       • dim_customers    │
│  • raw_products      • stg_products        enriched          • fct_orders       │
│  • raw_orders        • stg_orders        • int_customer_     • mart_product_    │
│  • raw_order_items   • stg_order_items     orders              performance      │
│  • raw_returns       • stg_returns       • int_product_      • fct_rfm_analysis │
│                                            performance                          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Transformation** | dbt Core 1.5+ | Industry-standard transformation framework |
| **SQL Dialect** | DuckDB (default) | Fast local development, zero config |
| **Alternative Warehouses** | PostgreSQL, Snowflake, BigQuery | Production-ready configurations included |
| **Testing** | dbt tests + dbt_expectations | Comprehensive data quality |
| **Documentation** | dbt docs | Auto-generated lineage and docs |

### Data Modeling Approach

**Dimensional Modeling (Kimball methodology)** was chosen for the following reasons:

1. **Business-Friendly**: Dimensions and facts map directly to business concepts
2. **Query Performance**: Star schema optimizes analytical queries
3. **Flexibility**: Supports ad-hoc analysis across multiple dimensions
4. **Industry Standard**: Widely understood by analysts and BI tools

#### Entity-Relationship Diagram (ERD)

```
                                    ┌─────────────────────┐
                                    │    dim_customers    │
                                    ├─────────────────────┤
                                    │ customer_id (PK)    │
                                    │ email               │
                                    │ customer_segment    │
                                    │ country             │
                                    │ total_orders        │
                                    │ total_revenue       │
                                    │ first_order_date    │
                                    │ last_order_date     │
                                    └──────────┬──────────┘
                                               │
                                               │ 1:N
                                               ▼
┌─────────────────────┐            ┌─────────────────────┐            ┌─────────────────────┐
│      dim_date       │            │     fct_orders      │            │mart_product_perform.│
├─────────────────────┤            ├─────────────────────┤            ├─────────────────────┤
│ date_id (PK)        │◀───────────│ order_id (PK)       │            │ product_id (PK)     │
│ year                │            │ user_id (FK)        │            │ product_name        │
│ month               │            │ order_date (FK)     │            │ category            │
│ quarter             │            │ customer_email      │            │ total_quantity_sold │
│ day_of_week         │            │ subtotal            │            │ total_revenue       │
│ is_weekend          │            │ is_returned         │            │ return_rate         │
└─────────────────────┘            │ days_to_return      │            │ gross_profit        │
                                   └─────────┬───────────┘            │ profit_margin       │
                                             │                        └─────────────────────┘
                                             │ 1:N
                                             ▼
                                   ┌─────────────────────┐
                                   │   fct_order_items   │
                                   ├─────────────────────┤
                                   │ order_item_id (PK)  │
                                   │ order_id (FK)       │
                                   │ product_id (FK)     │
                                   │ quantity            │
                                   │ unit_price          │
                                   │ is_returned         │
                                   └─────────────────────┘
```

#### Data Lineage

```
raw_users ──▶ stg_users ──┬──▶ int_customer_orders ──▶ dim_customers
                          │
raw_products ──▶ stg_products ──┬──▶ int_product_performance ──▶ mart_product_performance
                                │
raw_orders ──▶ stg_orders ──────┼──▶ int_orders_enriched ──┬──▶ fct_orders
                                │                          │
raw_order_items ──▶ stg_order_items ──┴──▶ int_order_items_enriched ──▶ fct_order_items
                                │
raw_returns ──▶ stg_returns ────┘
```

---

## Getting Started

### Prerequisites

- Python 3.8+
- pip (Python package manager)
- Git

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/ecommerce-analytics-dbt.git
cd ecommerce-analytics-dbt

# 2. Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dbt with DuckDB adapter
pip install dbt-duckdb

# 4. Install dbt packages
dbt deps
```

### Database Connection (profiles.yml)

The project includes a `profiles.yml` for reference. For production use, copy to `~/.dbt/profiles.yml`:

```yaml
ecommerce_analytics:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'ecommerce_analytics.duckdb'
      threads: 4
```

For other warehouses (PostgreSQL, Snowflake, BigQuery), see commented examples in `profiles.yml`.

### Running the Pipeline

```bash
# Step 1: Load seed data (CSV files)
dbt seed

# Step 2: Create SCD Type 2 snapshots
dbt snapshot

# Step 3: Run all models
dbt run

# Step 4: Run tests
dbt test

# Step 5: Generate and view documentation
dbt docs generate
dbt docs serve
```

### Full Pipeline Command

```bash
# Run everything in dependency order
dbt build

# Or run each step separately
dbt seed && dbt snapshot && dbt run && dbt test
```

---

## Project Structure

```
ecommerce-analytics-dbt/
├── analyses/                    # Ad-hoc analytical queries
│   ├── executive_summary.sql
│   ├── customer_segmentation_summary.sql
│   ├── weekly_revenue_trend.sql
│   └── ...
├── macros/                      # Reusable SQL macros
│   ├── datediff.sql
│   ├── date_trunc.sql
│   ├── extract_email_domain.sql
│   ├── safe_divide.sql
│   └── ...
├── models/
│   ├── staging/                 # Source-conformed models
│   │   ├── stg_users.sql + .yml
│   │   ├── stg_products.sql + .yml
│   │   ├── stg_orders.sql + .yml
│   │   ├── stg_order_items.sql + .yml
│   │   ├── stg_returns.sql + .yml
│   │   └── _sources.yml
│   ├── intermediate/            # Business logic layer
│   │   ├── int_order_items_enriched.sql + .yml
│   │   ├── int_orders_enriched.sql + .yml
│   │   ├── int_customer_orders.sql + .yml
│   │   └── int_product_performance.sql + .yml
│   └── marts/
│       ├── core/                # Primary dimensional models
│       │   ├── dim_customers.sql + .yml
│       │   ├── dim_date.sql + .yml
│       │   ├── fct_orders.sql + .yml (INCREMENTAL)
│       │   ├── fct_order_items.sql + .yml
│       │   └── mart_product_performance.sql + .yml
│       ├── finance/
│       │   ├── fct_daily_revenue.sql + .yml
│       │   └── fct_product_profitability.sql + .yml
│       └── marketing/
│           ├── fct_customer_cohorts.sql + .yml
│           ├── fct_customer_segments.sql + .yml
│           └── fct_rfm_analysis.sql + .yml
├── seeds/                       # Raw CSV data
│   ├── raw_users.csv + .yml
│   ├── raw_products.csv + .yml
│   ├── raw_orders.csv + .yml
│   ├── raw_order_items.csv + .yml
│   └── raw_returns.csv + .yml
├── snapshots/                   # SCD Type 2 snapshots
│   ├── snap_customers.sql + .yml
│   └── snap_products.sql + .yml
├── tests/                       # Custom data tests
│   ├── generic/                 # Reusable schema tests
│   └── *.sql                    # Singular tests
├── dbt_project.yml
├── packages.yml
└── profiles.yml
```

---

## Data Models

### Required Models

| Model | Type | Description |
|-------|------|-------------|
| `fct_orders` | Fact | Order transactions with customer/product dimensions |
| `dim_customers` | Dimension | Customer master with lifetime metrics |
| `mart_product_performance` | Mart | Product-level sales and profitability |
| `fct_rfm_analysis` | Mart | RFM customer segmentation (additional) |

### All Models Summary

| Layer | Model | Materialization | Description |
|-------|-------|-----------------|-------------|
| Staging | stg_users | View | Cleaned user data |
| Staging | stg_products | View | Cleaned product catalog |
| Staging | stg_orders | View | Cleaned order headers |
| Staging | stg_order_items | View | Cleaned line items |
| Staging | stg_returns | View | Cleaned returns data |
| Intermediate | int_order_items_enriched | View | Items with full context |
| Intermediate | int_orders_enriched | View | Orders with aggregations |
| Intermediate | int_customer_orders | View | Customer-level metrics |
| Intermediate | int_product_performance | View | Product-level metrics |
| Marts | dim_customers | Table | Customer dimension |
| Marts | dim_date | Table | Date dimension |
| Marts | fct_orders | **Incremental** | Order fact |
| Marts | fct_order_items | Table | Line item fact |
| Marts | mart_product_performance | Table | Product analytics |
| Marts | fct_daily_revenue | Table | Daily revenue |
| Marts | fct_customer_cohorts | Table | Cohort analysis |
| Marts | fct_rfm_analysis | Table | RFM segmentation |

---

## Incremental Models

### Why Incremental?

**fct_orders** uses incremental materialization because:

1. **Order data grows continuously** - Full refresh becomes expensive at scale
2. **Late-arriving data** - Returns can be processed days after the original order
3. **Status updates** - Orders may change status (e.g., completed → returned)

**Why not other models?**
- **fct_order_items**: Items don't change after creation—no late-arriving updates
- **fct_daily_revenue**: Small table (~365 rows/year) with window functions (cumulative totals, moving averages) that require full dataset recalculation—complexity outweighs benefits

### Incremental Strategy

```sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns'
    )
}}
```

### Late-Arriving Data Handling

Orders may receive returns days after the original transaction. Our strategy:

```sql
{% if is_incremental() %}
    -- Look back 3 days to capture returns and status changes
    where order_date >= (select max(order_date) - interval '3 days' from {{ this }})
{% endif %}
```

### Running Incremental Models

```bash
# Normal incremental run
dbt run --select fct_orders

# Full refresh (rebuild entire table)
dbt run --select fct_orders --full-refresh
```

---

## Testing Strategy

### Test Coverage

| Test Type | Count | Purpose |
|-----------|-------|---------|
| Generic (schema) | 50+ | Uniqueness, not null, relationships, accepted values |
| Singular | 4 | Business logic validation |
| Custom Schema | 3 | Reusable patterns (positive_value, valid_email, date_not_in_future) |

### Generic Tests

Applied via YAML schema files:

```yaml
columns:
  - name: customer_id
    data_tests:
      - unique
      - not_null
      - relationships:
          to: ref('dim_customers')
          field: customer_id
```

### Singular Tests (Custom Business Logic)

| Test | Purpose |
|------|---------|
| `assert_order_items_match_order_total` | Line items sum ≈ order total |
| `assert_refund_not_greater_than_order` | Refunds don't exceed order value |
| `assert_customers_have_valid_orders` | Referential integrity |
| `assert_no_orphan_order_items` | No orphaned line items |

### Custom Schema Tests

Reusable test macros in `tests/generic/`:

```sql
-- tests/generic/test_positive_value.sql
{% test positive_value(model, column_name, allow_zero=true) %}
select *
from {{ model }}
where {{ column_name }} < {% if allow_zero %}0{% else %}= 0{% endif %}
{% endtest %}
```

### Running Tests

```bash
dbt test                           # All tests
dbt test --select dim_customers    # Specific model
dbt test --select test_type:singular  # Only singular tests
```

---

## Performance Considerations

### Materialization Strategy

| Layer | Materialization | Rationale |
|-------|-----------------|-----------|
| Staging | View | No storage cost, always fresh, minimal compute |
| Intermediate | View | Reusable logic without data duplication |
| Marts (dimensions) | Table | Fast lookups for BI tools and joins |
| Marts (facts) | Table/Incremental | Query performance; incremental for high-volume |
| Ephemeral | Not used | Avoided to maintain debuggability and lineage visibility |

**Why these choices?**
- **Views for staging/intermediate**: These layers transform data but don't need persistence. Views ensure downstream models always see fresh data without storage overhead.
- **Tables for marts**: BI tools and analysts query marts directly. Tables provide consistent query performance regardless of upstream complexity.
- **Incremental for fct_orders**: Orders grow continuously. Full refresh at scale (millions of rows) would be expensive; incremental processes only new/changed data.

### Indexing and Clustering Strategy

For production deployment, the following indexing strategies are recommended:

| Model | Recommended Index/Cluster Keys | Rationale |
|-------|-------------------------------|-----------|
| fct_orders | `order_date`, `user_id` | Most queries filter by date range or customer |
| fct_order_items | `order_id`, `product_id` | Joins to orders and product lookups |
| dim_customers | `customer_id`, `customer_segment` | Primary key lookups and segment filtering |
| mart_product_performance | `category`, `product_id` | Category-level aggregations common |
| fct_daily_revenue | `date_id` | Time-series queries always filter by date |

**Implementation by warehouse:**

```sql
-- Snowflake: Clustering (automatic micro-partitioning + explicit clustering)
{{ config(
    materialized='incremental',
    cluster_by=['order_date', 'customer_segment']
) }}

-- BigQuery: Partitioning + Clustering
{{ config(
    materialized='incremental',
    partition_by={'field': 'order_date', 'data_type': 'date', 'granularity': 'day'},
    cluster_by=['customer_segment', 'order_status']
) }}

-- Redshift: Sort and Distribution keys
{{ config(
    materialized='incremental',
    sort=['order_date'],
    dist='user_id'  -- Collocate customer data for efficient joins
) }}

-- PostgreSQL: Explicit indexes via post-hook
{{ config(
    materialized='table',
    post_hook=[
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_order_date ON {{ this }} (order_date)",
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_user_id ON {{ this }} (user_id)"
    ]
) }}
```

### Partitioning Strategy

For large fact tables, partitioning by date is essential:

| Model | Partition Key | Granularity | Rationale |
|-------|--------------|-------------|-----------|
| fct_orders | order_date | Daily | Most queries filter by date range |
| fct_order_items | order_date | Daily | Aligns with order partitioning |
| fct_daily_revenue | date_id | Daily | One partition per day (natural grain) |

**Benefits:**
- **Partition pruning**: Queries filtering by date only scan relevant partitions
- **Efficient incremental loads**: New data lands in new partitions
- **Simplified maintenance**: Old partitions can be archived or dropped

### Query Optimization Techniques

1. **Incremental Loading**: `fct_orders` processes only recent data (3-day lookback window)
2. **Pre-aggregation**: Metrics computed once in intermediate layer, reused across marts
3. **Denormalization**: Customer segment stored in `fct_orders` to avoid joins for common filters
4. **Selective Column Projection**: Models select only needed columns from upstream
5. **Early Filtering**: Staging models apply `is_completed` filters to reduce downstream data volume

### Performance at Scale

| Data Volume | Recommended Approach |
|-------------|---------------------|
| < 1M rows | Full refresh tables work fine |
| 1M - 100M rows | Incremental models essential; add clustering |
| > 100M rows | Partitioning required; consider aggregate tables |

For this project's dataset (~200 orders), any materialization works. The incremental pattern demonstrates production-readiness for scale.

---

## Advanced Features

### 1. Exposures

Downstream dependencies are documented in `models/exposures.yml`:

```yaml
exposures:
  - name: executive_dashboard
    type: dashboard
    depends_on:
      - ref('fct_orders')
      - ref('dim_customers')
```

### 2. Snapshots (SCD Type 2)

Track historical changes to customer segment and product pricing:

```sql
-- snapshots/snap_customers.sql
{% snapshot snap_customers %}
{{
    config(
        strategy='check',
        check_cols=['customer_segment', 'country']
    )
}}
select * from {{ ref('raw_users') }}
{% endsnapshot %}
```

### 3. Hooks

Post-hooks for logging and monitoring:

```sql
{{
    config(
        post_hook=[
            "{{ log('fct_orders refreshed at ' ~ run_started_at, info=True) }}"
        ]
    )
}}
```

### 4. Packages

External packages in `packages.yml`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<0.11.0"]
```

### 5. Analysis Files

Complex analytical queries in `analyses/`:
- `executive_summary.sql` - KPI dashboard
- `weekly_revenue_trend.sql` - Week-over-week analysis
- `cohort_retention_matrix.sql` - Retention curves

---

## Sample Query Outputs

### Example 1: Customer Lifetime Value

```sql
SELECT
  customer_id,
  email,
  customer_segment,
  total_orders,
  total_revenue,
  avg_order_value,
  first_order_date,
  last_order_date,
  days_since_last_order
FROM dim_customers
WHERE customer_segment = 'Premium'
ORDER BY total_revenue DESC
LIMIT 10;
```

**Actual Output (verified):**

| customer_id | email | customer_segment | total_orders | total_revenue | avg_order_value | first_order_date | last_order_date | days_since_last_order |
|-------------|-------|------------------|--------------|---------------|-----------------|------------------|-----------------|----------------------|
| 17 | quinn.lewis@email.com | Premium | 4 | 731.00 | 182.75 | 2023-05-10 | 2023-06-22 | 923 |
| 23 | wendy.scott@email.com | Premium | 3 | 698.00 | 232.67 | 2023-05-13 | 2023-06-23 | 922 |
| 32 | felix.turner@email.com | Premium | 3 | 678.00 | 226.00 | 2023-05-18 | 2023-06-25 | 920 |
| 5 | emma.davis@email.com | Premium | 4 | 604.00 | 151.00 | 2023-05-03 | 2023-06-20 | 925 |
| 20 | tina.allen@email.com | Premium | 4 | 535.50 | 133.88 | 2023-05-11 | 2023-06-23 | 922 |

### Example 2: Product Performance with Returns

```sql
SELECT
  product_id,
  product_name,
  category,
  total_quantity_sold,
  total_revenue,
  total_returns,
  return_rate,
  gross_profit,
  profit_margin
FROM mart_product_performance
WHERE return_rate > 0.10
ORDER BY return_rate DESC;
```

**Actual Output (verified):**

| product_id | product_name | category | total_quantity_sold | total_revenue | total_returns | return_rate | gross_profit | profit_margin |
|------------|--------------|----------|---------------------|---------------|---------------|-------------|--------------|---------------|
| 118 | Standing Desk | Furniture | 12 | 3239.00 | 6 | 0.500 | 239.00 | 0.074 |
| 113 | Monitor | Electronics | 21 | 4112.00 | 9 | 0.429 | 332.00 | 0.081 |
| 106 | Ergonomic Chair | Furniture | 6 | 741.00 | 1 | 0.167 | 21.00 | 0.028 |
| 102 | Mechanical Keyboard | Electronics | 9 | 420.50 | 1 | 0.111 | 15.50 | 0.037 |

### Example 3: Orders with Returns

```sql
SELECT
  order_id,
  order_date,
  customer_email,
  customer_segment,
  order_status,
  total_items,
  total_quantity,
  subtotal,
  is_returned,
  days_to_return
FROM fct_orders
WHERE is_returned = TRUE
ORDER BY order_date DESC
LIMIT 5;
```

**Actual Output (verified):**

| order_id | order_date | customer_email | customer_segment | order_status | total_items | total_quantity | subtotal | is_returned | days_to_return |
|----------|------------|----------------|------------------|--------------|-------------|----------------|----------|-------------|----------------|
| 1090 | 2023-06-14 | jack.anderson@email.com | Standard | completed | 1 | 1 | 215.00 | true | 49 |
| 1084 | 2023-06-11 | derek.perez@email.com | Standard | completed | 1 | 1 | 255.00 | true | 47 |
| 1078 | 2023-06-08 | kate.thomas@email.com | Premium | completed | 1 | 1 | 235.00 | true | 47 |
| 1072 | 2023-06-05 | felix.turner@email.com | Premium | completed | 1 | 1 | 295.00 | true | 47 |
| 1066 | 2023-06-02 | olivia.harris@email.com | Standard | completed | 1 | 1 | 265.00 | true | 46 |

### Example 4: Monthly Trends

```sql
SELECT
  DATE_TRUNC('month', order_date) as order_month,
  COUNT(DISTINCT order_id) as total_orders,
  COUNT(DISTINCT user_id) as unique_customers,
  SUM(subtotal) as total_revenue,
  AVG(subtotal) as avg_order_value
FROM fct_orders
WHERE order_status = 'completed'
GROUP BY 1
ORDER BY 1;
```

**Actual Output (verified):**

| order_month | total_orders | unique_customers | total_revenue | avg_order_value |
|-------------|--------------|------------------|---------------|-----------------|
| 2023-05-01 | 59 | 39 | 6,863.49 | 116.33 |
| 2023-06-01 | 58 | 38 | 6,780.50 | 116.91 |

---

## Design Decisions

### 1. Individual YAML Files per Model

**Decision**: Each model has its own `.yml` file instead of combined files.

**Rationale**:
- Reduces merge conflicts in team environments
- Easier to locate documentation
- Follows "single responsibility" principle
- dbt Labs recommended for large projects

### 2. Dimensional Modeling over One Big Table

**Decision**: Star schema with facts and dimensions.

**Rationale**:
- BI tools optimize for star schema queries
- Clear separation of measures vs attributes
- Reusable dimensions across multiple facts
- Industry standard for analytics

### 3. Incremental for fct_orders Only

**Decision**: Only `fct_orders` uses incremental materialization.

**Rationale**:
- Order data grows continuously and receives late-arriving updates (returns)
- Other fact tables either don't receive updates (fct_order_items) or are small aggregates where full refresh is simpler (fct_daily_revenue)
- 3-day lookback handles late-arriving returns
- Merge strategy handles updates cleanly

### 4. Views for Staging/Intermediate

**Decision**: Staging and intermediate models are views.

**Rationale**:
- Zero storage cost
- Always reflects latest source data
- Fast compilation
- Tables only where query performance matters

---

## Assumptions

### Business Domain Assumptions

1. **Order Status**: Only "completed" and "cancelled" statuses exist
2. **Returns**: Can only occur after order completion, within reasonable timeframe
3. **Pricing**: Unit prices at time of purchase may differ from current catalog prices
4. **Customer Segments**: Assigned at registration, may not reflect current behavior
5. **Refunds**: Typically equal to or less than original order value

### Data Quality Assumptions

1. **Referential Integrity**: All foreign keys resolve to valid records
2. **Date Consistency**: Order dates are always before or equal to return dates
3. **No Duplicates**: Source data has unique primary keys
4. **Complete Data**: No significant gaps in transaction history

### Technical Assumptions

1. **Timezone**: All dates are in a single timezone
2. **Currency**: All monetary values are in USD
3. **Incremental Window**: 3-day lookback sufficient for late-arriving data

---

## Submission Notes

### Time Spent

Approximately 3.5 hours for complete implementation including:
- Project structure and configuration
- All models (staging, intermediate, marts)
- Testing and documentation
- Incremental model implementation
- Advanced features (snapshots, exposures, hooks)

### What I Would Improve With More Time

1. **CI/CD Pipeline**: Add GitHub Actions for automated testing ✅ Implemented
2. **Data Contracts**: Implement dbt contracts for schema enforcement
3. **Metrics Layer**: Add semantic layer with dbt metrics
4. **More Snapshots**: Track order status changes over time
5. **Performance Benchmarking**: Document query execution times ✅ Implemented

### Challenges and Solutions

1. **Late-Arriving Returns**: Solved with 3-day lookback window in incremental models
2. **Window Functions in Incremental**: For fct_daily_revenue, combined existing data with new data before calculating cumulative metrics
3. **Column Naming**: Aligned output columns with expected format in assessment

---

## Additional Documentation

For deeper technical details, see the following documentation:

| Document | Description |
|----------|-------------|
| [CI/CD Workflows](.github/workflows/dbt_ci.yml) | GitHub Actions for automated testing, deployment, and Slim CI |
| [Performance Guide](docs/PERFORMANCE.md) | Benchmarking results, optimization techniques, scaling recommendations |
| [Data Lineage](docs/DATA_LINEAGE.md) | Visual lineage diagrams, critical path analysis, impact analysis |
| [dbt Cloud Guide](docs/DBT_CLOUD.md) | Cloud-specific features, job configuration, semantic layer setup |

### Quick Links

- **CI/CD**: Runs automatically on push/PR via GitHub Actions
- **Generate lineage**: `dbt docs generate && dbt docs serve`
- **View execution stats**: Check `target/run_results.json` after builds

---

## License

MIT License
