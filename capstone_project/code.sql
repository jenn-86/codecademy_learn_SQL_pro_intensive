-- Table familiarisation
SELECT *
FROM subscriptions
LIMIT 100;

-- Determine range of months and which months can be used to calculate churn
SELECT MIN(subscription_start) AS 'earliest_subscription_date',
    MAX(subscription_start) AS 'latest_subscription_date'
FROM subscriptions;

-- Number of segments and their subscription counts
SELECT segment,
    COUNT(segment) AS 'subscription_count'
FROM subscriptions
GROUP BY 1;

-- Churn Calculation Overall
-- 1. Temporary 'months' table
WITH months AS (
  SELECT
        '2017-01-01' AS 'first_day',
        '2017-01-31' AS 'last_day'
    UNION
    SELECT
        '2017-02-01' AS 'first_day',
        '2017-02-28' AS 'last_day'
    UNION
    SELECT
        '2017-03-01' AS 'first_day',
        '2017-03-31' AS 'last_day'),
        
-- 2. Temporary 'cross_join' table
cross_join AS (
    SELECT *
    FROM subscriptions
    CROSS JOIN months),
    
-- 3. Temporary 'status' table with 'is_active' and 'is_canceled' columns
status AS (
    SELECT id,
        first_day AS 'month',
        CASE WHEN (subscription_start < first_day)
                  AND (
                    (subscription_end >= first_day)
                    OR subscription_end IS NULL
                  ) THEN 1
             ELSE 0
        END AS 'is_active',        
        CASE WHEN ( subscription_end
                    BETWEEN first_day AND last_day
                  ) THEN 1
             ELSE 0
        END AS 'is_canceled'
    FROM cross_join),

-- 4. Temporary 'status_aggregate' table
status_aggregate AS (
    SELECT month,
        SUM(is_active)   AS 'sum_active',
        SUM(is_canceled) AS 'sum_canceled'
    FROM status
    GROUP BY 1)
    
-- 5. Calculate churn rates over the three month period.
SELECT month,
    1.0 * sum_canceled/sum_active AS 'churn_rate'
FROM status_aggregate
GROUP BY 1
ORDER BY 1 ASC;

-- Churn Calculation by Segment - first round
-- 1. Temporary 'months' table
WITH months AS (
  SELECT
        '2017-01-01' AS 'first_day',
        '2017-01-31' AS 'last_day'
    UNION
    SELECT
        '2017-02-01' AS 'first_day',
        '2017-02-28' AS 'last_day'
    UNION
    SELECT
        '2017-03-01' AS 'first_day',
        '2017-03-31' AS 'last_day'),
        
-- 2. Temporary 'cross_join' table
cross_join AS (
    SELECT *
    FROM subscriptions
    CROSS JOIN months),
    
-- 3. Temporary 'status' table with 'is_active' and 'is_canceled' columns for segments 87 and 30
status AS (
    SELECT id,
        first_day AS 'month',
        CASE WHEN (segment = 87)
                  AND (subscription_start < first_day)
                  AND (
                    subscription_end >= first_day
                    OR subscription_end IS NULL
                  ) THEN 1
             ELSE 0
        END AS 'is_active_87',
        CASE WHEN segment = 30
                  AND subscription_start < first_day
                  AND (
                    subscription_end >= first_day
                    OR subscription_end IS NULL
                  ) THEN 1
             ELSE 0
        END AS 'is_active_30',
        CASE WHEN (segment = 87)
                  AND (
                    subscription_end
                    BETWEEN first_day AND last_day
                  ) THEN 1
             ELSE 0
        END AS 'is_canceled_87',
        CASE WHEN (segment = 30)
                  AND (
                    subscription_end
                  	BETWEEN first_day AND last_day
                  ) THEN 1
             ELSE 0
        END AS 'is_canceled_30'
    FROM cross_join),

-- 4. Temporary 'status_aggregate' table that is a SUM of the active & canceled subscriptions for each month
status_aggregate AS (
    SELECT month,
        SUM(is_active_87)   AS 'sum_active_87',
        SUM(is_active_30)   AS 'sum_active_30',
        SUM(is_canceled_87) AS 'sum_canceled_87',
        SUM(is_canceled_30) AS 'sum_canceled_30'
    FROM status
    GROUP BY 1)
    
-- 5. Calculate churn rates over the three month period. Which segment has the lower churn rate?
SELECT month,
    1.0 * sum_canceled_87/sum_active_87 AS 'churn_rate_87',
    1.0 * sum_canceled_30/sum_active_30 AS 'churn_rate_30'
FROM status_aggregate
GROUP BY 1
ORDER BY 1 ASC;

-- Churn Calculation by Segment - BONUS avoiding hard coding of segment names
-- 1. Temporary 'months' table
WITH months AS (
  SELECT
        '2017-01-01' AS 'first_day',
        '2017-01-31' AS 'last_day'
    UNION
    SELECT
        '2017-02-01' AS 'first_day',
        '2017-02-28' AS 'last_day'
    UNION
    SELECT
        '2017-03-01' AS 'first_day',
        '2017-03-31' AS 'last_day'),
        
-- 2. Bonus -  Create distinct table of segments to include in cross_join table
segments AS (
    SELECT DISTINCT segment AS 'segment_group'
    FROM subscriptions),
    
-- 3. Temporary 'cross_join' table
cross_join AS (
    SELECT *
    FROM subscriptions
    CROSS JOIN months
    CROSS JOIN segments),
    
-- 4. Temporary 'status' table using segment_group column to calculate by segment
status AS (
    SELECT id,
        first_day AS 'month',
        segment_group,
        CASE WHEN (segment = segment_group)
                  AND (subscription_start < first_day)
                  AND (
                    (subscription_end >= first_day)
                    OR subscription_end IS NULL
                  ) THEN 1
             ELSE 0
        END AS 'is_active',
        CASE WHEN (segment = segment_group)
                  AND (
                      subscription_end
                      BETWEEN first_day AND last_day
                  ) THEN 1
             ELSE 0
        END AS 'is_canceled'
    FROM cross_join),
    
-- 5. Temporary 'status_aggregate' table that is a SUM of the active & canceled subscriptions for each month
status_aggregate AS (
    SELECT month,
        segment_group,
        SUM (is_active) AS 'sum_active',
        SUM (is_canceled) AS 'sum_canceled'
    FROM status
    GROUP BY 1, 2),
    
-- 6. Calculate churn rates over the three month period. Which segment has the lower churn rate?
churn_calculation AS (
    SELECT month,
        segment_group,
        1.0 * sum_canceled/sum_active AS 'churn_rate'
    FROM status_aggregate
    GROUP BY 2, 1
    ORDER BY 2, 1 ASC)

-- 7. Bonus - Pivot the segment groups
SELECT month,
    MAX (CASE WHEN segment_group = '87' THEN churn_rate END) AS 'churn_rate_87',
    MAX (CASE WHEN segment_group = '30' THEN churn_rate END) AS 'churn_rate_30'
FROM churn_calculation
GROUP BY 1
ORDER BY 1 ASC;
