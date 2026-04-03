-- Month-over-Month Growth using LAG Window Function
WITH monthly_revenue AS (
    -- 1. Calculate total revenue per month
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        SUM(p.payment_value) * 16.5 AS revenue_inr
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
),
mom_growth AS (
    -- 2. Use LAG to pull the previous month's revenue into the current row
    SELECT 
        order_month,
        revenue_inr,
        LAG(revenue_inr) OVER (ORDER BY order_month) AS prev_month_revenue
    FROM monthly_revenue
)
-- 3. Calculate the percentage growth
SELECT 
    TO_CHAR(order_month, 'YYYY-MM') AS month,
    ROUND(revenue_inr, 2) AS current_revenue_inr,
    ROUND(prev_month_revenue, 2) AS previous_revenue_inr,
    ROUND(((revenue_inr - prev_month_revenue) / prev_month_revenue) * 100, 2) AS growth_percentage
FROM mom_growth
WHERE prev_month_revenue IS NOT NULL
ORDER BY order_month;