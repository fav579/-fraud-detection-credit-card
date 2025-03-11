-- SQL Key Questions
-- Customer Analysis
-- What is the spending behavior of high-value customers? (e.g top 10% spenders)
WITH CustomerSpending AS (
    SELECT 
        cc_num,
        round(SUM(amt),0) AS total_spent
    FROM 
[credit_card_transactions].[dbo].[cc_transactions]  
GROUP BY 
        cc_num
),
PercentileRanks AS (
    SELECT 
        cc_num,
        total_spent,
        NTILE(10) OVER (ORDER BY total_spent DESC) AS percentile_rank
    FROM 
        CustomerSpending
)
SELECT 
    cc_num,
    total_spent
FROM 
    PercentileRanks
WHERE 
    percentile_rank = 1 -- Top 10% percentile
ORDER BY 
    total_spent DESC;
    
-- What is the distribution of transaction amounts by customer gender?
select gender, count(*) as total_transaction,
round(sum(amt),2) as transaction_amount,
round(avg(amt),2) as Average_amount,
Min(amt) as minimum_amount,
round(max(amt),2) as maximum_amount
from [credit_card_transactions].[dbo].[cc_transactions]
group by gender
order by total_transaction;

-- What is the total amount spent by each customer (cc_num) over a specified time period?
 select 
    cc_num,
 count(*) as number_of_transactions
    from [credit_card_transactions].[dbo].[cc_transactions]
    where trans_date_trans_time between '1/1/2019'and '3/31/2019'
    group by cc_num
    order by number_of_transactions;

	
-- Which customers have the highest average transaction amount?
select top 10 cc_num, round(avg(amt),2) as Average_amount
from [credit_card_transactions].[dbo].[cc_transactions]
group by cc_num
order by Average_amount desc;

-- How many transactions has each customer made, and what is the average amount per transaction?
select cc_num, round(count(*),2) as total_transactions, round(avg(amt),2) as Average_amount
from [credit_card_transactions].[dbo].[cc_transactions]
group by cc_num
order by total_transactions;


-- What is the maximum amount a customer has spent in a single transaction?
select top 1 cc_num, round(sum(amt),2) as maximum_amount
from [credit_card_transactions].[dbo].[cc_transactions]
group by cc_num
order by maximum_amount desc;

-- Merchant Analysis
-- Which merchant categories have the highest average transaction amount?
select top 10 category, round(avg(amt),2) as Average_amount
from [credit_card_transactions].[dbo].[cc_transactions]
group by category
order by Average_amount desc;


-- How do merchants' revenue growth rates vary over time?
WITH Revenue_Per_Year AS (
    SELECT 
        YEAR(CAST(trans_date_trans_time AS DATE)) AS year,
        SUM(amt) AS total_revenue
    FROM [credit_card_transactions].[dbo].[cc_transactions]
    GROUP BY YEAR(CAST(trans_date_trans_time AS DATE))
)
SELECT 
    year,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY year) AS previous_year_revenue,
    ((total_revenue - LAG(total_revenue) OVER (ORDER BY year)) / LAG(total_revenue) OVER (ORDER BY year)) * 100 AS revenue_growth_rate
FROM Revenue_Per_Year
ORDER BY year DESC;


-- Which merchant locations are most frequently visited by customers?
select top 10 merch_zipcode, city,count(*) as total_visits
from cc_transactions
group by merch_zipcode, city
order by total_visits desc;

-- Which merchants are associated with the highest number of fradulent transactions?
select top 20 merchant, count(*) as total_transactions
from [credit_card_transactions].[dbo].[cc_transactions]
where is_fraud = 1
group by merchant
order by total_transactions desc;

-- Merchant-customer relationship
-- Analyze repeat transactions between specific customers & merchants
SELECT 
    cc_num AS Customer_ID,
    merchant AS Merchant,
    COUNT(*) AS Transaction_Count
FROM 
    [credit_card_transactions].[dbo].[cc_transactions]
GROUP BY 
    cc_num, merchant
HAVING 
    COUNT(*) > 1
ORDER BY 
    Transaction_Count DESC;


-- Profitability analysis
--
-- profitability analysis trend over time
SELECT YEAR(trans_date_trans_time) AS Year,
 CASE 
        WHEN MONTH(trans_date_trans_time) BETWEEN 1 AND 3 THEN 'Q1'
        WHEN MONTH(trans_date_trans_time) BETWEEN 4 AND 6 THEN 'Q2'
        WHEN MONTH(trans_date_trans_time) BETWEEN 7 AND 9 THEN 'Q3'
        ELSE 'Q4'
    END AS Quarter,

    FORMAT(trans_date_trans_time, 'MMMM') AS Month,
	DATEPART(WEEK, trans_date_trans_time) AS Week,
	 DATEPART(Day, trans_date_trans_time) AS Day,
	 DATENAME(WEEKDAY, trans_date_trans_time) AS Day_name,
    round(SUM(amt),2) AS total_amount,
    round(AVG(amt),2) AS avg_amount
FROM [credit_card_transactions].[dbo].[cc_transactions]
GROUP BY CASE 
        WHEN MONTH(trans_date_trans_time) BETWEEN 1 AND 3 THEN 'Q1'
        WHEN MONTH(trans_date_trans_time) BETWEEN 4 AND 6 THEN 'Q2'
        WHEN MONTH(trans_date_trans_time) BETWEEN 7 AND 9 THEN 'Q3'
        ELSE 'Q4'
    END ,YEAR(trans_date_trans_time),
    FORMAT(trans_date_trans_time, 'MMMM'),
	DATEPART(WEEK, trans_date_trans_time),
	 DATEPART(Day, trans_date_trans_time),
	 DATENAME(WEEKDAY, trans_date_trans_time)
ORDER BY Year,Quarter, Month,Week, Day;


--FRAUD DETECTION AND PREVENTION AND TRANSACTION ANALYSIS
--How do fraudulent transactions compare to non-fraudulent in terms of average amount
SELECT 
    CASE 
        WHEN is_fraud = 1 THEN 'Fraudulent'
        ELSE 'Non-Fraudulent'
    END AS Transaction_type,
    round(AVG(amt),2) AS avg_amount
FROM [credit_card_transactions].[dbo].[cc_transactions]
GROUP BY 
    CASE 
        WHEN is_fraud = 1 THEN 'Fraudulent'
        ELSE 'Non-Fraudulent'
    END
ORDER BY 
    transaction_type;

--What is the average time between fraudulent transactions for each merchant or merchant category?
WITH FraudulentTransactions AS (
    SELECT 
        merchant,
        trans_date_trans_time,
        LAG(trans_date_trans_time) OVER (
            PARTITION BY merchant
            ORDER BY trans_date_trans_time
        ) AS previous_trans_time
    FROM [credit_card_transactions].[dbo].[cc_transactions]
    WHERE is_fraud = 1
),
TimeDifferences AS (
    SELECT 
        merchant,
        DATEDIFF(SECOND, previous_trans_time, trans_date_trans_time) AS time_diff_seconds
    FROM FraudulentTransactions
    WHERE previous_trans_time IS NOT NULL
)
SELECT 
    merchant,
    AVG(time_diff_seconds) / 3600.0 AS avg_time_hours --converting seconds to hours
FROM TimeDifferences
GROUP BY merchant
ORDER BY avg_time_hours DESC;


--Use patterns in amount, transaction date/time and location differences (customer vs merchant) to flag potential fraud

--Calculate Z-scores or other statistical methods to detect outliers in transaction amounts.
WITH Stats AS (
    SELECT 
        AVG(amt) AS mean_amount,
        STDEV(amt) AS stddev_amount
    FROM [credit_card_transactions].[dbo].[cc_transactions]
),
ZScores AS (
    SELECT 
        t.*,
        (amt - s.mean_amount) / s.stddev_amount AS z_score
    FROM [credit_card_transactions].[dbo].[cc_transactions] t
    CROSS JOIN Stats s
)
SELECT 
    trans_date_trans_time,
    cc_num,
    merchant,
    category,
    amt,
    z_score
FROM ZScores
WHERE ABS(z_score) > 3 -- Flagging transactions with Z-scores > 3 as potential outliers
ORDER BY z_score DESC;
