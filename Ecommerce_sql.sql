use depiecommerce;

-- CEO (Growth & Strategy)
-- KPI Revenue|orders 
CREATE VIEW ceo_total_revenue_view AS
    (SELECT 
       *
    FROM
       CFO_total_revenue);

-- KPI Refunds
CREATE VIEW ceo_total_refund_view AS(
    SELECT 
        SUM(COALESCE(refund_amount_usd, 0)) AS total_refunds
    FROM
        order_item_refunds);

 -- sessions vs orders 
 CREATE VIEW ceo_sessions_orders_per_month_view AS(
 SELECT
    MONTH(ws.created_at) AS month_number,
    DATE_FORMAT(ws.created_at, '%M') AS month_name,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM website_sessions ws
LEFT JOIN orders o 
    ON ws.website_session_id = o.website_session_id
GROUP BY MONTH(ws.created_at), DATE_FORMAT(ws.created_at, '%M')
ORDER BY month_number);

-- KPI RPS| orders|sessions 
create view ceo_revenue_per_session_view as (SELECT 
    SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id) AS revenue_per_session
FROM website_sessions ws
LEFT JOIN orders o 
    ON ws.website_session_id = o.website_session_id);

-- KPI AOV 
create view ceo_avg_order_value_view as 
(SELECT SUM(o.price_usd) / COUNT(DISTINCT o.order_id) AS average_order_value 
FROM
website_sessions AS ws 
    LEFT JOIN
    orders AS o ON ws.website_session_id = o.website_session_id);
-- KPI CR 
 CREATE VIEW ceo_conversion_rate_view AS
    (SELECT 
        ROUND(COUNT(DISTINCT order_id) * 1.0 / COUNT(DISTINCT ws.website_session_id) * 100,
                2) AS conversion_rate
    FROM
        website_sessions ws
            LEFT JOIN
        orders o ON ws.website_session_id = o.website_session_id);
-- KPI Net revenue
CREATE VIEW ceo_net_revenue_view AS (
    SELECT 
        (SUM(o.price_usd) - SUM(COALESCE(oir.refund_amount_usd, 0))) AS net_revenue
    FROM
        orders o
            LEFT JOIN
        order_item_refunds oir ON o.order_id = oir.order_id);

  -- KPI Orders 
CREATE VIEW ceo_total_orders_view AS
    (SELECT 
        COUNT(order_id) AS total_orders
    FROM
        orders);

use test;
-- KPI SESSION
CREATE VIEW ceo_total_sessions_view AS
    (SELECT 
        COUNT(website_session_id) AS total_sessions
    FROM
        website_sessions);

    
-- sessions|orders|revenue
CREATE VIEW ceo_orders_sessions_year AS (
SELECT 
    DATE_FORMAT(ws.created_at, '%Y') AS year,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(o.price_usd) AS total_revenue
FROM website_sessions ws
LEFT JOIN orders o 
    ON ws.website_session_id = o.website_session_id
GROUP BY DATE_FORMAT(ws.created_at, '%Y')
ORDER BY year);


-- rowth over 3 years 
create view INV_Growth_over_3_years as (
WITH yearly_data AS (
    SELECT 
        YEAR(ws.created_at) AS year,
        COUNT(DISTINCT ws.website_session_id) AS total_sessions,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(o.price_usd) AS total_revenue
    FROM website_sessions ws
    LEFT JOIN orders o 
        ON ws.website_session_id = o.website_session_id
    WHERE YEAR(ws.created_at) < 2015  
    GROUP BY YEAR(ws.created_at)
)
SELECT 
    yd.year,
    yd.total_sessions,
    yd.total_orders,
    yd.total_revenue,
    ROUND(
        (yd.total_sessions - LAG(yd.total_sessions) OVER (ORDER BY yd.year)) 
        / LAG(yd.total_sessions) OVER (ORDER BY yd.year) * 100, 2
    ) AS sessions_growth_pct,
    ROUND(
        (yd.total_orders - LAG(yd.total_orders) OVER (ORDER BY yd.year)) 
        / LAG(yd.total_orders) OVER (ORDER BY yd.year) * 100, 2
    ) AS orders_growth_pct,
    ROUND(
        (yd.total_revenue - LAG(yd.total_revenue) OVER (ORDER BY yd.year)) 
        / LAG(yd.total_revenue) OVER (ORDER BY yd.year) * 100, 2
    ) AS revenue_growth_pct
FROM yearly_data yd
ORDER BY yd.year);

CREATE VIEW INV_Product_Revenue AS(
  SELECT
  oi.product_id,
  p.product_name,
  SUM(oi.price_usd) AS product_revenue
FROM order_items oi
JOIN products p 
  ON oi.product_id = p.product_id
GROUP BY oi.product_id, p.product_name
ORDER BY product_revenue DESC);
  
  -- MIX CHANNEL
  create view INV_Channel_diversification as(
 WITH sessions_with_channel AS (
  SELECT
    ws.website_session_id,
    CASE
      WHEN ws.utm_source IS NULL AND ws.http_referer IS NULL THEN 'Direct'
      WHEN ws.utm_source IS NULL AND ws.http_referer LIKE '%gsearch%' THEN 'gsearch'
      WHEN ws.utm_source IS NULL AND ws.http_referer LIKE '%bsearch%' THEN 'bsearch'
      WHEN ws.utm_source IS NULL AND ws.http_referer LIKE '%social%' THEN 'socialbook'
      WHEN ws.utm_source IS NULL THEN 'Other'
      ELSE ws.utm_source
    END AS channel
  FROM website_sessions ws
)
SELECT
  swc.channel,
  COUNT(o.order_id) AS total_orders,
  ROUND(
    COUNT(o.order_id) * 1.0 / SUM(COUNT(o.order_id)) OVER (),
    4
  ) AS channel_pct
FROM sessions_with_channel swc
JOIN orders o 
  ON swc.website_session_id = o.website_session_id
GROUP BY swc.channel
ORDER BY channel_pct DESC);
-- CVR + RPS
create view INV_Efficiency_Gains as(
SELECT
  COALESCE(ws.utm_source, 'Direct') AS channel,
  ws.device_type,
  ROUND(COUNT(o.order_id) * 1.0 / COUNT(ws.website_session_id), 4) AS CVR,       
  ROUND(SUM(o.price_usd) / COUNT(ws.website_session_id), 2) AS RPS               
FROM website_sessions ws
LEFT JOIN orders o 
  ON ws.website_session_id = o.website_session_id
GROUP BY COALESCE(ws.utm_source, 'Direct'), ws.device_type
ORDER BY channel, ws.device_type);

-- Net Margin 
create view INV_Net_Margin as (
  SELECT
  DATE_FORMAT(o.created_at, '%Y') AS year,
  SUM(o.price_usd - o.cogs_usd) AS net_profit,
  SUM(o.price_usd) AS revenue,
  ROUND(SUM(o.price_usd - o.cogs_usd) / SUM(o.price_usd), 4) AS net_margin
FROM orders o
GROUP BY DATE_FORMAT(o.created_at, '%Y')
ORDER BY year);
  
  
  
  CREATE VIEW revenue_breakdown AS (
SELECT
  YEAR(`orders`.`created_at`) AS `year`,
  SUM(`orders`.`price_usd`) AS `revenue`,
  SUM(
    COALESCE(`order_item_refunds`.`refund_amount_usd`, 0)
  ) AS `refunds`,
  SUM(`orders`.`price_usd`) - SUM(
    COALESCE(`order_item_refunds`.`refund_amount_usd`, 0)
  ) AS `net_revenue`
FROM
  `orders`
  LEFT JOIN `order_item_refunds` ON `orders`.`order_id` = `order_item_refunds`.`order_id`
GROUP BY
  YEAR(`orders`.`created_at`)
ORDER BY
  `year`);
------------------------------------------------------------------

-- CMO_sessions_orders_by_channel_device
CREATE VIEW CMO_sessions_orders_by_channel_device AS(
SELECT 
    ws.device_type,
    COALESCE(ws.utm_source, ws.http_referer, 'direct') AS channel,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type, channel
ORDER BY total_sessions DESC);
 select * from CMO_sessions_orders_by_channel_device;
 --
 
 -- CMO_cvr_by_channel_device
CREATE OR REPLACE VIEW CMO_cvr_by_channel_device AS
SELECT
    ws.device_type,
    COALESCE(ws.utm_source, ws.http_referer, 'direct') AS channel,
    COUNT(ws.website_session_id) AS sessions,
    COUNT(o.order_id) AS orders,
    (COUNT(o.order_id) * 1.0 / COUNT(ws.website_session_id)) * 100 AS conversion_rate
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type, channel
ORDER BY conversion_rate DESC ;

Select * from CMO_cvr_by_channel_device;
--

-- CMO_rpc_by_channel_device
CREATE OR REPLACE VIEW CMO_rpc_by_channel_device AS
SELECT 
    ws.device_type,
    COALESCE(ws.utm_source, ws.http_referer, 'direct') AS channel,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    SUM(o.price_usd) AS total_revenue,
    CAST(SUM(o.price_usd) AS DECIMAL(12,2)) / NULLIF(COUNT(DISTINCT ws.website_session_id),0) AS rpc
FROM website_sessions ws
JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type, channel
;
select * from CMO_rpc_by_channel_device ;


--
-- CMO_new_vs_repeat_report
CREATE VIEW CMO_new_vs_repeat_report AS
SELECT
    CASE 
        WHEN ws.is_repeat_session = 0 THEN 'New Customer'
        WHEN ws.is_repeat_session = 1 THEN 'Repeat Customer'
    END AS customer_type,
    
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(o.price_usd) AS total_revenue,
    
    ROUND(COUNT(DISTINCT o.order_id) * 1.0 / COUNT(DISTINCT ws.website_session_id), 3) AS CVR,
    ROUND(SUM(o.price_usd) * 1.0 / COUNT(DISTINCT ws.website_session_id), 2) AS RPS,
    ROUND(SUM(o.price_usd) * 1.0 / NULLIF(COUNT(DISTINCT ws.user_id),0), 2) AS RPR
    
FROM website_sessions ws
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id
GROUP BY ws.is_repeat_session;
SELECT * FROM CMO_new_vs_repeat_report;
--

-- CMO_customer_loyalty
CREATE OR REPLACE VIEW CMO_customer_loyalty AS
SELECT 
    user_id,
    website_session_id,
    created_at AS session_date,
    COALESCE(
        CAST(LAG(created_at) OVER (PARTITION BY user_id ORDER BY created_at) AS CHAR),
        'No Previous'
    ) AS prev_session_date,
    COALESCE(
        CAST(DATEDIFF(
            created_at,
            LAG(created_at) OVER (PARTITION BY user_id ORDER BY created_at)
        ) AS CHAR),
        'Not Exist'
    ) AS days_between_visits
FROM website_sessions;

SELECT * FROM CMO_customer_loyalty;


-------------------------------------------------------------
-- Website Performance Manager

-- (1) Top Pages (Most visited pages)
CREATE VIEW top_pages AS
SELECT 
    pageview_url,
    COUNT(*) AS views
FROM depiecommerce.website_pageviews
GROUP BY pageview_url
ORDER BY views DESC;

-- (2) Entry Pages (First page per session)
CREATE VIEW entry_pages AS
SELECT 
    w.website_session_id,
    MIN(wp.created_at) AS first_page_time,
    SUBSTRING_INDEX(
        SUBSTRING_INDEX(GROUP_CONCAT(wp.pageview_url ORDER BY wp.created_at), ',', 1),
        ',', -1
    ) AS entry_page
FROM depiecommerce.website_sessions w
JOIN depiecommerce.website_pageviews wp 
    ON w.website_session_id = wp.website_session_id
GROUP BY w.website_session_id;

-- (3) Bounce Rate (sessions with only 1 pageview)
CREATE VIEW bounce_rate AS
SELECT 
    entry_page,
    COUNT(CASE WHEN pageviews = 1 THEN 1 END) * 100.0 / COUNT(*) AS bounce_rate_percent
FROM (
    SELECT 
        w.website_session_id,
        COUNT(wp.website_pageview_id) AS pageviews,
        MIN(wp.pageview_url) AS entry_page
    FROM depiecommerce.website_sessions w
    JOIN depiecommerce.website_pageviews wp 
        ON w.website_session_id = wp.website_session_id
    GROUP BY w.website_session_id
) session_summary
GROUP BY entry_page;

-- (4) Funnel Conversion % (Homepage → Product → Checkout → Order)
CREATE OR REPLACE VIEW funnel_conversion AS
SELECT 
    COUNT(DISTINCT s.website_session_id) AS Total_Sessions,
    
    -- Homepage Visits
    COUNT(DISTINCT CASE WHEN wp.pageview_url = '/home' THEN s.website_session_id END) AS Homepage_Visits,
    
    -- Product Visits (any product or /products page)
    COUNT(DISTINCT CASE 
        WHEN wp.pageview_url = '/products'
          OR wp.pageview_url LIKE '/the-%'
        THEN s.website_session_id END) AS Product_Visits,
    
    -- Checkout Visits (cart + shipping + billing)
    COUNT(DISTINCT CASE 
        WHEN wp.pageview_url IN ('/cart','/shipping','/billing','/billing-2')
        THEN s.website_session_id END) AS Checkout_Visits,
    
    -- Completed Orders (thank you page)
    COUNT(DISTINCT CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN s.website_session_id END) AS Completed_Orders

FROM depiecommerce.website_sessions s
LEFT JOIN depiecommerce.website_pageviews wp 
    ON s.website_session_id = wp.website_session_id;
    
-- (5) A/B Test Results (by Campaign / Content)
CREATE VIEW ab_test_results AS
SELECT 
    s.utm_campaign AS Campaign,
    s.utm_content AS Test_Group,
    COUNT(DISTINCT s.website_session_id) AS Sessions,
    COUNT(DISTINCT o.order_id) AS Orders,
    ROUND(
        COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT s.website_session_id),
        2
    ) AS Conversion_Rate_Percent
FROM depiecommerce.website_sessions s
LEFT JOIN depiecommerce.orders o 
    ON s.website_session_id = o.website_session_id
GROUP BY s.utm_campaign, s.utm_content
ORDER BY Conversion_Rate_Percent DESC;
    
SELECT * FROM top_pages;
SELECT * FROM entry_pages;
SELECT * FROM bounce_rate;
SELECT * FROM funnel_conversion;
SELECT * FROM ab_test_results;

------------------------------------------------------- 
-- CFO analysis
-- CFO Summary
CREATE OR REPLACE VIEW CFO_Store_Summary AS
SELECT
    -- Total Revenue
    ROUND(SUM(o.price_usd), 2) AS total_revenue,

    -- Total Orders
    COUNT(DISTINCT o.order_id) AS total_orders,

    -- Average Order Value (AOV)
    ROUND(AVG(o.price_usd), 2) AS average_order_value,

    -- Total Gross Margin + %
    ROUND(SUM(o.price_usd - o.cogs_usd), 2) AS total_gross_margin,
    CONCAT(ROUND((SUM(o.price_usd - o.cogs_usd) / NULLIF(SUM(o.price_usd), 0)) * 100, 2), '%') AS gross_margin_percentage,

    -- Refund Rate ( order_item_refunds)
    CONCAT(ROUND(
        (COUNT(DISTINCT r.order_item_refund_id) / NULLIF(COUNT(DISTINCT o.order_id), 0)) * 100, 
    2), '%') AS refund_rate
FROM orders o
LEFT JOIN order_item_refunds r 
    ON o.order_id = r.order_id;

-- Products performance
CREATE OR REPLACE VIEW CFO_Product_Performance AS
SELECT 
    p.product_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.price_usd), 2) AS total_revenue,
    ROUND(SUM(o.price_usd - o.cogs_usd), 2) AS total_margin,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value,
    CONCAT(ROUND(
        (COUNT(DISTINCT r.order_item_refund_id) / NULLIF(COUNT(DISTINCT o.order_id),0)) * 100, 2
    ), '%') AS refund_rate
FROM products p
LEFT JOIN orders o 
    ON o.primary_product_id = p.product_id
LEFT JOIN order_item_refunds r 
    ON o.order_id = r.order_id
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- Incremental Test Gains
CREATE OR REPLACE VIEW CFO_Incremental_Test_Gains AS
SELECT 
    ws.utm_campaign,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(o.price_usd), 2) AS revenue,
    ROUND(AVG(o.price_usd), 2) AS avg_order_value
FROM website_sessions ws
LEFT JOIN orders o 
    ON ws.website_session_id = o.website_session_id
WHERE ws.utm_campaign IS NOT NULL
GROUP BY ws.utm_campaign
ORDER BY revenue DESC;   


-- Conversion Funnel Analysis
CREATE OR REPLACE VIEW CFO_Conversion_Funnel AS
SELECT 
    COUNT(DISTINCT CASE WHEN wp.pageview_url = '/products' THEN ws.website_session_id END) AS product_page_sessions,
    COUNT(DISTINCT o.website_session_id) AS order_sessions,
    CONCAT(ROUND(
        (COUNT(DISTINCT o.website_session_id) / NULLIF(COUNT(DISTINCT CASE 
            WHEN wp.pageview_url = '/products' THEN ws.website_session_id END), 0)) * 100,
    2), '%') AS conversion_rate_from_products_page
FROM website_sessions ws
LEFT JOIN website_pageviews wp 
    ON ws.website_session_id = wp.website_session_id
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id;
    

CREATE VIEW coo_seasonality_view AS
-- Monthly seasonality
SELECT 
    YEAR(created_at) AS year,
    MONTH(created_at) AS month,
    COUNT(*) AS total_orders,
    'monthly' AS period_type
FROM orders
GROUP BY YEAR(created_at), MONTH(created_at)

UNION ALL

-- Weekly seasonality
SELECT 
    YEAR(created_at) AS year,
    WEEK(created_at) AS week,
    COUNT(*) AS total_orders,
    'weekly' AS period_type
FROM orders
GROUP BY YEAR(created_at), WEEK(created_at);

-- coo_refund_rates
CREATE OR REPLACE VIEW coo_refund_rates AS
SELECT 
    o.primary_product_id,
    ROUND(
        COUNT(DISTINCT r.order_item_refund_id) * 1.0 / NULLIF(COUNT(DISTINCT o.order_id),0), 
        2
    ) AS refund_rate
FROM orders o
LEFT JOIN order_item_refunds r 
    ON o.order_id = r.order_id
GROUP BY o.primary_product_id
ORDER BY refund_rate DESC;

-- coo_daily_hourly_traffic
CREATE OR REPLACE VIEW coo_daily_hourly_traffic AS
SELECT 
    DATE(o.created_at) AS order_date,
    HOUR(o.created_at) AS order_hour,
    COUNT(DISTINCT o.website_session_id) AS total_sessions
FROM orders o
GROUP BY DATE(o.created_at), HOUR(o.created_at)
ORDER BY order_date, order_hour;
