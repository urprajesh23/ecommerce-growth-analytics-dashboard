-- Cohort Retention Analysis
WITH first_purchase AS (
    -- 1. Find the first time each customer made a purchase (Their Cohort)
    SELECT 
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
user_activity AS (
    -- 2. Map every purchase a user made to a specific month
    SELECT 
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
),
cohort_size AS (
    -- 3. Count how many total users are in each original cohort
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS total_users
    FROM first_purchase
    GROUP BY cohort_month
),
retention_base AS (
    -- 4. Calculate the "Month Number" (0 = first month, 1 = second month, etc.)
    SELECT 
        fp.cohort_month,
        EXTRACT(YEAR FROM ua.activity_month) * 12 + EXTRACT(MONTH FROM ua.activity_month) -
        (EXTRACT(YEAR FROM fp.cohort_month) * 12 + EXTRACT(MONTH FROM fp.cohort_month)) AS month_number,
        COUNT(DISTINCT ua.customer_unique_id) AS retained_users
    FROM first_purchase fp
    JOIN user_activity ua ON fp.customer_unique_id = ua.customer_unique_id
    GROUP BY fp.cohort_month, ua.activity_month, month_number
)
-- 5. Calculate the retention percentage
SELECT 
    TO_CHAR(rb.cohort_month, 'YYYY-MM') AS cohort,
    cs.total_users,
    rb.month_number,
    rb.retained_users,
    ROUND((rb.retained_users::NUMERIC / cs.total_users) * 100, 2) AS retention_percentage
FROM retention_base rb
JOIN cohort_size cs ON rb.cohort_month = cs.cohort_month
WHERE rb.month_number <= 6 -- Looking at the first 6 months of retention
ORDER BY rb.cohort_month, rb.month_number;