-- RFM Segmentation Query
-- Converts BRL to INR (* 16.5) and uses NTILE window functions for scoring

WITH rfm_base AS (
    -- 1. Calculate the raw Recency, Frequency, and Monetary values per user
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(p.payment_value) * 16.5 AS monetary_value_inr 
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_calc AS (
    -- 2. Calculate Recency in exact days (using the max date in the dataset as "today")
    SELECT 
        customer_unique_id,
        EXTRACT(DAY FROM (SELECT MAX(order_purchase_timestamp) FROM orders) - last_purchase_date) AS recency_days,
        frequency,
        monetary_value_inr
    FROM rfm_base
),
rfm_scores AS (
    -- 3. Use NTILE window function to bucket customers into groups of 1 to 5
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value_inr,
        -- For Recency: Lower days is better, so we sort DESC (5 is most recent)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        -- For Frequency & Monetary: Higher is better, so we sort ASC
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value_inr ASC) AS m_score
    FROM rfm_calc
)
-- 4. Assign business labels based on the scores
SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    ROUND(monetary_value_inr, 2) AS monetary_value_inr,
    r_score,
    f_score,
    m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Potential Loyalists'
    END AS customer_segment
FROM rfm_scores;