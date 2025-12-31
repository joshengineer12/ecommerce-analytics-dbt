# dbt Cloud Features & Configuration

This document outlines how this project is designed to leverage dbt Cloud features and metadata capabilities.

## Table of Contents
- [dbt Cloud Compatibility](#dbt-cloud-compatibility)
- [Environment Configuration](#environment-configuration)
- [Job Scheduling](#job-scheduling)
- [Metadata & Discovery](#metadata--discovery)
- [Advanced Features](#advanced-features)

---

## dbt Cloud Compatibility

### Project Structure for dbt Cloud

This project follows dbt Cloud best practices:

```
ecommerce-analytics-dbt/
├── dbt_project.yml          # Cloud-compatible configuration
├── profiles.yml             # Local only (not used in Cloud)
├── packages.yml             # Package dependencies
├── models/
│   ├── staging/             # Source transformations
│   ├── intermediate/        # Business logic
│   └── marts/               # Business-ready models
├── seeds/                   # Reference data
├── snapshots/               # SCD tracking
├── macros/                  # Reusable logic
├── tests/                   # Custom tests
└── analyses/                # Ad-hoc queries
```

### Key Compatibility Features

| Feature | Status | Notes |
|---------|--------|-------|
| Incremental models | ✅ | Uses `merge` strategy (warehouse-agnostic) |
| Snapshots | ✅ | SCD Type 2 with `check` strategy |
| Custom schemas | ✅ | Configured per environment |
| Packages | ✅ | Using dbt_utils, dbt_expectations |
| Exposures | ✅ | Downstream dependencies documented |
| Model contracts | ⚡ | Ready to enable for critical models |

---

## Environment Configuration

### Recommended dbt Cloud Environments

```yaml
# Environment: Development
name: Development
type: development
dbt_version: 1.8+
custom_branch: feature/*
target_name: dev
schema_prefix: dev_

# Environment: Staging
name: Staging
type: staging
dbt_version: 1.8+
custom_branch: develop
target_name: staging
schema_prefix: stg_

# Environment: Production
name: Production
type: production
dbt_version: 1.8+
custom_branch: main
target_name: prod
schema_prefix: prod_
```

### Environment-Specific Variables

```yaml
# dbt_project.yml
vars:
  # Default values (overridden in Cloud)
  target_schema: 'analytics'

  # Date range for testing (dev only)
  dev_start_date: '2024-01-01'

  # Feature flags
  enable_profiling: false
  enable_contracts: true
```

### Custom Schema Macro (dbt Cloud Ready)

```sql
-- macros/get_custom_schema.sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {%- set default_schema = target.schema -%}

    {%- if target.name == 'prod' -%}
        {# Production: use custom schema directly #}
        {{ custom_schema_name | trim if custom_schema_name else default_schema }}
    {%- else -%}
        {# Dev/Staging: prefix with target schema #}
        {{ default_schema }}_{{ custom_schema_name | trim if custom_schema_name else 'default' }}
    {%- endif -%}
{% endmacro %}
```

---

## Job Scheduling

### Recommended Job Configuration

#### 1. Production Daily Build

```yaml
name: Production - Daily Build
environment: Production
schedule:
  cron: "0 6 * * *"  # 6 AM UTC daily
commands:
  - dbt source freshness
  - dbt build --exclude tag:weekly
  - dbt run-operation log_build_stats
settings:
  threads: 8
  target: prod
  generate_docs: true
triggers:
  on_merge_to_main: true
```

#### 2. Production Weekly Build

```yaml
name: Production - Weekly Full Refresh
environment: Production
schedule:
  cron: "0 3 * * 0"  # 3 AM UTC Sundays
commands:
  - dbt run --full-refresh --select tag:weekly
  - dbt test --select tag:weekly
settings:
  threads: 8
  target: prod
```

#### 3. Slim CI Job (Pull Requests)

```yaml
name: CI - Slim Build
environment: Staging
trigger:
  pull_request: true
  branches: [main, develop]
commands:
  - dbt build --select state:modified+ --defer --favor-state
settings:
  threads: 4
  target: ci
  compare_manifest: production
```

### Job Dependencies

```
┌─────────────────────────────────────────────────────────┐
│                  JOB ORCHESTRATION                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ┌──────────────┐                                       │
│   │ Source       │ 5:30 AM                               │
│   │ Freshness    │────┐                                  │
│   └──────────────┘    │                                  │
│                       ▼                                  │
│   ┌──────────────┐  ┌──────────────┐                    │
│   │ Staging      │  │ Snapshot     │ 6:00 AM            │
│   │ Models       │──│ Job          │────┐               │
│   └──────────────┘  └──────────────┘    │               │
│                                          ▼               │
│                     ┌──────────────────────────────────┐ │
│                     │ Main Build (fct_, dim_, mart_)   │ │
│                     │ 6:15 AM                          │ │
│                     └──────────────────────────────────┘ │
│                                          │               │
│                                          ▼               │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│   │ Test Suite   │  │ Generate     │  │ Notify       │  │
│   │              │──│ Docs         │──│ Slack        │  │
│   └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Metadata & Discovery

### Exposures for dbt Cloud Discovery

Our exposures enable dbt Cloud's discovery features:

```yaml
# models/marts/_exposures.yml
exposures:
  - name: executive_dashboard
    type: dashboard
    maturity: high
    url: https://looker.company.com/dashboards/1
    description: C-suite KPI dashboard

    depends_on:
      - ref('fct_daily_revenue')
      - ref('dim_customers')
      - ref('fct_orders')

    owner:
      name: Data Team
      email: data@company.com

    meta:
      priority: critical
      sla: 99.9%
      refresh_frequency: daily
```

### Model Metadata for Discovery

```yaml
# Example model with rich metadata
models:
  - name: fct_orders
    description: "{{ doc('fct_orders') }}"

    meta:
      owner: analytics-team
      tier: gold
      pii: false
      contains_pii_columns: [customer_email]

      # dbt Cloud specific
      priority: high
      domain: sales
      data_classification: internal

      # SLA tracking
      freshness_sla_hours: 6
      expected_row_count_min: 100
```

### Using dbt Cloud Artifacts API

```python
# Example: Query dbt Cloud metadata API
import requests

DBT_CLOUD_API = "https://metadata.cloud.getdbt.com/graphql"
TOKEN = "your-service-token"

query = """
{
  models(
    filter: { projectId: 12345 }
  ) {
    uniqueId
    name
    description
    meta
    stats {
      rowCount
      lastModifiedAt
    }
  }
}
"""

response = requests.post(
    DBT_CLOUD_API,
    headers={"Authorization": f"Bearer {TOKEN}"},
    json={"query": query}
)
```

---

## Advanced Features

### 1. Model Contracts (dbt 1.5+)

Ready to enable for critical models:

```yaml
# models/marts/core/fct_orders.yml
models:
  - name: fct_orders
    config:
      contract:
        enforced: true

    columns:
      - name: order_id
        data_type: varchar
        constraints:
          - type: not_null
          - type: primary_key

      - name: total_amount
        data_type: decimal(18,2)
        constraints:
          - type: not_null
          - type: check
            expression: "total_amount >= 0"
```

### 2. Model Versions (dbt 1.6+)

For breaking changes:

```yaml
models:
  - name: dim_customers
    latest_version: 2
    versions:
      - v: 1
        deprecation_date: 2025-03-01
      - v: 2
        columns:
          - include: all
          - name: customer_ltv
            description: "New LTV calculation"
```

### 3. Semantic Layer (dbt Cloud)

```yaml
# models/semantic/metrics.yml
semantic_models:
  - name: orders
    defaults:
      agg_time_dimension: order_date

    model: ref('fct_orders')

    entities:
      - name: order
        type: primary
        expr: order_id
      - name: customer
        type: foreign
        expr: customer_id

    dimensions:
      - name: order_date
        type: time
        type_params:
          time_granularity: day
      - name: region
        type: categorical

    measures:
      - name: total_revenue
        agg: sum
        expr: total_amount
      - name: order_count
        agg: count
        expr: order_id

metrics:
  - name: revenue
    type: simple
    type_params:
      measure: total_revenue

  - name: average_order_value
    type: derived
    type_params:
      expr: total_revenue / order_count
```

### 4. dbt Explorer Configuration

```yaml
# dbt_project.yml additions for Explorer
meta:
  # Project-level metadata
  team: analytics
  domain: ecommerce
  documentation:
    wiki: https://wiki.company.com/analytics
    slack: "#data-questions"

# Enable column-level lineage
flags:
  require_explicit_package_overrides_for_builtin_materializations: true
```

---

## Migration Path to dbt Cloud

### Phase 1: Basic Setup
1. Connect Git repository
2. Configure warehouse connection
3. Set up development environment
4. Test builds manually

### Phase 2: CI/CD
1. Enable Slim CI for pull requests
2. Configure production deployment job
3. Set up Slack notifications

### Phase 3: Advanced Features
1. Enable Discovery (metadata API)
2. Configure semantic layer
3. Set up model contracts
4. Implement cross-project refs (if multi-project)

### Phase 4: Governance
1. Define environment permissions
2. Set up audit logging
3. Configure SSO/SAML
4. Implement data classification

---

*This project is designed for seamless migration to dbt Cloud while maintaining local development capability.*
*Last Updated: December 2024*
