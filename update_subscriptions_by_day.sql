-- update_subscriptions_by_day.sql

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'unique_subscription_entry'
    ) THEN
        -- Add the unique constraint if it doesn't exist
        ALTER TABLE subscriptions_by_day
        ADD CONSTRAINT unique_subscription_entry UNIQUE (date, status, metro_id, utm_source, utm_medium, utm_campaign);
    END IF;
END $$;

WITH max_date AS (
    SELECT DATE(MAX(created_at)) - INTERVAL '1 day' AS latest_date
    FROM api_subscriptions
),
data AS (
    SELECT 
        subs.created_at,
        subs.canceled_at,
        subs.unpaid_at,
        subs.trial_end,
        subs.customer_id,
        COALESCE(NULLIF(CAST(cust.metro_id AS TEXT), ''), 'Unknown') AS metro_id,
        COALESCE(NULLIF(cust.utm::json->>'source', ''), 'Unknown') AS utm_source,
        COALESCE(NULLIF(cust.utm::json->>'medium', ''), 'Unknown') AS utm_medium,
        COALESCE(NULLIF(cust.utm::json->>'campaign', ''), 'Unknown') AS utm_campaign,
        subs.source AS source_x
    FROM 
        api_subscriptions subs
    LEFT JOIN 
        api_customers cust ON subs.customer_id = cust.id
    WHERE 
        LOWER(subs.source) = 'stripe'
),
status_data AS (
    SELECT 
        md.latest_date AS created_date,
        CASE
            WHEN d.canceled_at IS NOT NULL AND d.canceled_at <= md.latest_date THEN 'Canceled'
            WHEN d.unpaid_at IS NOT NULL AND d.unpaid_at <= md.latest_date THEN 'Unpaid'
            WHEN d.trial_end IS NOT NULL AND d.trial_end > md.latest_date AND d.created_at <= md.latest_date THEN 'Trialing'
            WHEN d.created_at <= md.latest_date THEN 'Active'
            ELSE NULL
        END AS status,
        d.metro_id,
        d.utm_source,
        d.utm_medium,
        d.utm_campaign
    FROM 
        data d
    CROSS JOIN 
        max_date md
    WHERE 
        DATE(d.created_at) <= md.latest_date
)
INSERT INTO subscriptions_by_day (date, status, metro_id, utm_source, utm_medium, utm_campaign, subscription_count)
SELECT 
    created_date AS date,
    status,
    metro_id,
    utm_source,
    utm_medium,
    utm_campaign,
    COUNT(*) AS subscription_count
FROM 
    status_data
WHERE 
    status IS NOT NULL
GROUP BY 
    created_date, status, metro_id, utm_source, utm_medium, utm_campaign
ORDER BY 
    created_date, status, metro_id, utm_source, utm_medium, utm_campaign
ON CONFLICT (date, status, metro_id, utm_source, utm_medium, utm_campaign) DO UPDATE SET
subscription_count = EXCLUDED.subscription_count;
