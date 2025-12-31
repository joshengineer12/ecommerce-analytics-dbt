# Performance Benchmarking & Query Optimization

This document outlines performance considerations, benchmarking results, and optimization strategies for the e-commerce analytics dbt project.

## Table of Contents
- [Benchmark Results](#benchmark-results)
- [Materialization Strategy](#materialization-strategy)
- [Incremental Model Performance](#incremental-model-performance)
- [Query Optimization Techniques](#query-optimization-techniques)
- [Monitoring & Alerting](#monitoring--alerting)

---

## Benchmark Results

### Full Build Performance (DuckDB - Local Development)

| Metric | Value | Notes |
|--------|-------|-------|
| **Total Build Time** | ~7-9 seconds | Full `dbt build` including seeds, models, snapshots, tests |
| **Seeds** | 5 seeds, ~0.3s | 389 total rows loaded |
| **Staging Models** | 5 views, ~0.1s each | Minimal overhead as views |
| **Intermediate Models** | 4 views, ~0.1s each | Business logic layer |
| **Mart Models** | 10 tables, ~0.2-0.5s each | Materialized for query performance |
| **Snapshots** | 2 snapshots, ~0.5s each | SCD Type 2 tracking |
| **Tests** | 138 tests, ~3s total | Comprehensive data quality |

### Model Execution Times (Ranked)

```
Slowest Models:
1. dim_customers      - 0.45s (complex aggregations)
2. fct_orders         - 0.35s (incremental merge)
3. fct_rfm_analysis   - 0.25s (window functions)
4. dim_date           - 0.20s (date spine generation)
5. mart_product_perf  - 0.18s (product aggregations)
```

### Projected Production Performance

For a production dataset with ~10M orders:

| Model | Estimated Time | Strategy |
|-------|---------------|----------|
| fct_orders (incremental) | 30-60s | Daily incremental with 3-day lookback |
| fct_orders (full refresh) | 10-15min | Monthly full refresh recommended |
| dim_customers | 2-3min | Nightly rebuild |
| Snapshots | 1-2min | Capture daily changes |

---

## Materialization Strategy

### Decision Framework

```
┌─────────────────────────────────────────────────────────────┐
│                  Materialization Decision Tree               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Is the model queried directly by BI tools?                  │
│     │                                                        │
│     ├── YES → Is data volume > 1M rows?                      │
│     │         │                                              │
│     │         ├── YES → Does it need historical tracking?    │
│     │         │         │                                    │
│     │         │         ├── YES → INCREMENTAL                │
│     │         │         └── NO  → TABLE                      │
│     │         │                                              │
│     │         └── NO  → TABLE (fast enough)                  │
│     │                                                        │
│     └── NO → Is it referenced by multiple downstream models? │
│             │                                                │
│             ├── YES → TABLE (avoid recomputation)            │
│             └── NO  → VIEW (lightweight)                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Current Materializations

| Layer | Materialization | Rationale |
|-------|----------------|-----------|
| **Staging** | View | Lightweight transformations, always reflect source |
| **Intermediate** | View | Business logic, low overhead |
| **Dimensions** | Table | Frequently joined, stable data |
| **Facts** | Table/Incremental | Query performance, historical accuracy |
| **Marts** | Table | BI tool performance |
| **Snapshots** | Snapshot | SCD Type 2 by design |

---

## Incremental Model Performance

### fct_orders Incremental Strategy

```sql
-- Incremental configuration
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        on_schema_change='sync_all_columns'
    )
}}

-- Late-arriving data handling
{% if is_incremental() %}
    where order_date >= (
        select max(order_date) - interval '3 days'
        from {{ this }}
    )
{% endif %}
```

**Performance Characteristics:**

| Run Type | Records Processed | Time | Use Case |
|----------|------------------|------|----------|
| Full Refresh | All records | 100% | Initial load, schema changes |
| Incremental | Last 3 days | ~5% | Daily runs |
| Incremental (catch-up) | Last 7 days | ~10% | After outage |

### Why 3-Day Lookback?

1. **Late-arriving orders**: Some orders may be entered retroactively
2. **Status updates**: Order status can change (pending → completed)
3. **Return processing**: Returns link back to original orders
4. **Balance**: 3 days captures 99%+ of updates while keeping runs fast

---

## Query Optimization Techniques

### 1. Predicate Pushdown

```sql
-- GOOD: Filter early in CTEs
with completed_orders as (
    select * from {{ ref('stg_orders') }}
    where is_completed = true  -- Filter before joins
)

-- BAD: Filter late
with all_orders as (
    select * from {{ ref('stg_orders') }}
)
select * from all_orders
where is_completed = true  -- Late filtering
```

### 2. Selective Column Projection

```sql
-- GOOD: Select only needed columns
select
    order_id,
    user_id,
    order_date,
    total_amount
from {{ ref('stg_orders') }}

-- BAD: Select all columns
select * from {{ ref('stg_orders') }}
```

### 3. Efficient Aggregations

```sql
-- Using window functions efficiently
select
    product_id,
    sum(quantity) as total_sold,
    -- Compute rank only when needed
    row_number() over (
        partition by category
        order by sum(quantity) desc
    ) as category_rank
from {{ ref('int_order_items_enriched') }}
group by product_id, category
```

### 4. Join Optimization

```sql
-- GOOD: Join on indexed/primary keys
from orders o
inner join users u on o.user_id = u.user_id  -- PK join

-- Use LEFT JOIN only when nulls are expected
left join returns r on oi.order_item_id = r.order_item_id
```

### 5. Avoiding Expensive Operations

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `SELECT DISTINCT` on large tables | `GROUP BY` or proper keys | Less memory |
| `ORDER BY` in subqueries | Order only in final output | Unnecessary sorting |
| `UNION` | `UNION ALL` (if no duplicates) | Avoids dedup step |
| Correlated subqueries | Window functions or CTEs | Better execution plan |

---

## DuckDB-Specific Optimizations

### 1. Parallel Execution

DuckDB automatically parallelizes queries. Optimize by:
- Avoiding operations that force serialization
- Using appropriate data types (avoid strings for joins)

### 2. Memory Management

```yaml
# profiles.yml optimization
dev:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: 'ecommerce_analytics.duckdb'
      threads: 4  # Match CPU cores
      # memory_limit: '4GB'  # For larger datasets
```

### 3. File Format Considerations

For larger datasets, consider:
- Parquet files for staging (columnar, compressed)
- Delta Lake for incremental processing
- External tables for very large datasets

---

## Monitoring & Alerting

### Key Metrics to Track

```yaml
# Example monitoring configuration
metrics:
  - name: build_duration
    threshold: 300  # Alert if > 5 minutes

  - name: test_failures
    threshold: 0    # Alert on any failure

  - name: row_count_change
    threshold: 50   # Alert if > 50% change

  - name: freshness_lag
    threshold: 3600 # Alert if > 1 hour stale
```

### dbt Artifacts for Monitoring

| Artifact | Use Case |
|----------|----------|
| `manifest.json` | Model dependencies, lineage |
| `run_results.json` | Execution times, status |
| `catalog.json` | Schema documentation |
| `sources.json` | Source freshness |

### Alerting Integration

```python
# Example: Parse run_results.json for monitoring
import json

with open('target/run_results.json') as f:
    results = json.load(f)

failed = [r for r in results['results'] if r['status'] == 'error']
slow = [r for r in results['results'] if r['execution_time'] > 60]

if failed:
    send_alert(f"dbt build failed: {len(failed)} models")
if slow:
    send_alert(f"Slow models detected: {[r['unique_id'] for r in slow]}")
```

---

## Recommendations for Scale

### Short Term (Current → 1M rows)
- Current setup is sufficient
- Monitor incremental model performance
- Add indexes if migrating to PostgreSQL/Snowflake

### Medium Term (1M → 100M rows)
- Migrate to cloud data warehouse (Snowflake/BigQuery/Redshift)
- Implement clustering on fact tables
- Add partition pruning on date columns
- Consider dbt Cloud for orchestration

### Long Term (100M+ rows)
- Implement data vault 2.0 architecture
- Add real-time streaming layer (Kafka → staging)
- Implement blue-green deployments for zero-downtime
- Consider Databricks for ML integration

---

## Performance Testing Commands

```bash
# Time a full build
time dbt build

# Profile specific model
dbt run --select fct_orders --full-refresh 2>&1 | tee timing.log

# Compare incremental vs full refresh
time dbt run --select fct_orders                    # Incremental
time dbt run --select fct_orders --full-refresh     # Full

# Run with query profiling (DuckDB)
dbt run --vars '{"enable_profiling": true}'
```

---

*Last Updated: December 2024*
*Benchmark Environment: MacOS, Python 3.10, dbt-duckdb 1.10.0*
