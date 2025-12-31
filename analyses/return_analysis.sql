-- Return Analysis
-- Deep dive into returns by reason, product, and customer segment

with returns_detail as (
    select
        r.return_id,
        r.return_reason,
        r.return_reason_category,
        r.refund_amount,
        r.is_quality_issue,
        oi.product_name,
        oi.category,
        oi.supplier_id,
        o.customer_segment,
        o.region
    from {{ ref('stg_returns') }} r
    inner join {{ ref('int_order_items_enriched') }} oi on r.order_item_id = oi.order_item_id
    inner join {{ ref('int_orders_enriched') }} o on oi.order_id = o.order_id
),

-- Returns by Reason
by_reason as (
    select
        'By Reason' as analysis_type,
        return_reason as dimension,
        count(*) as return_count,
        sum(refund_amount) as total_refunds,
        round(avg(refund_amount), 2) as avg_refund
    from returns_detail
    group by 1, 2
),

-- Returns by Category
by_category as (
    select
        'By Category' as analysis_type,
        category as dimension,
        count(*) as return_count,
        sum(refund_amount) as total_refunds,
        round(avg(refund_amount), 2) as avg_refund
    from returns_detail
    group by 1, 2
),

-- Returns by Customer Segment
by_segment as (
    select
        'By Customer Segment' as analysis_type,
        customer_segment as dimension,
        count(*) as return_count,
        sum(refund_amount) as total_refunds,
        round(avg(refund_amount), 2) as avg_refund
    from returns_detail
    group by 1, 2
),

-- Quality Issues by Supplier
quality_by_supplier as (
    select
        'Quality Issues by Supplier' as analysis_type,
        supplier_id::text as dimension,
        count(*) as return_count,
        sum(refund_amount) as total_refunds,
        round(avg(refund_amount), 2) as avg_refund
    from returns_detail
    where is_quality_issue
    group by 1, 2
)

select * from by_reason
union all
select * from by_category
union all
select * from by_segment
union all
select * from quality_by_supplier
order by analysis_type, return_count desc
