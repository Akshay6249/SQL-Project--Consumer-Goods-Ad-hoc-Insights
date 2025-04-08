/* --------------------
   Codebasics SQL Challenge
   --------------------*/

/* 
1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
*/

-- Fetch distinct markets where customer "Atliq Exclusive" operates in APAC
SELECT DISTINCT market 
FROM dim_customer
WHERE customer = "Atliq Exclusive" AND region = "APAC";


/* 
2. What is the percentage of unique product increase in 2021 vs. 2020?
   The final output contains: unique_products_2020, unique_products_2021, percentage_chg
*/

-- Calculate total unique products per year and compare 2020 with 2021
WITH cte AS (
    SELECT COUNT(DISTINCT product_code) AS total_products, fiscal_year  
    FROM fact_sales_monthly
    GROUP BY fiscal_year
)
SELECT 
    a.total_products AS unique_products_2020, 
    b.total_products AS unique_products_2021, 
    (b.total_products - a.total_products) AS newly_launched_prod,
    ROUND((b.total_products - a.total_products) / a.total_products * 100, 2) AS pct_change  
FROM cte a 
LEFT JOIN cte b ON a.fiscal_year + 1 = b.fiscal_year
LIMIT 1;


/* 
3. Provide a report with all the unique product counts for each segment and sort them in descending order.
   Output: segment, product_count
*/

-- Count unique products per segment, sorted by count descending
SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product 
GROUP BY segment 
ORDER BY product_count DESC;


/* 
4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
   Output: segment, product_count_2020, product_count_2021, difference
*/

-- Compare product count per segment between 2020 and 2021
WITH tot_products AS (
    SELECT COUNT(DISTINCT fs.product_code) AS total_products, 
           fiscal_year, 
           segment
    FROM fact_sales_monthly fs 
    JOIN dim_product dp ON fs.product_code = dp.product_code
    GROUP BY fiscal_year, segment
)
SELECT 
    a.segment, 
    a.total_products AS unique_products_2020, 
    b.total_products AS unique_products_2021, 
    b.total_products - a.total_products AS difference,
    ROUND((b.total_products - a.total_products) / a.total_products * 100, 2) AS pct_change
FROM tot_products a 
LEFT JOIN tot_products b 
ON a.fiscal_year + 1 = b.fiscal_year AND a.segment = b.segment
WHERE b.total_products IS NOT NULL 
ORDER BY pct_change DESC;


/* 
5. Get the products that have the highest and lowest manufacturing costs.
   Output: product_code, product, manufacturing_cost
*/

-- Get max and min manufacturing cost products
(SELECT dp.product_code, dp.product, fm.manufacturing_cost 
 FROM fact_manufacturing_cost fm 
 JOIN dim_product dp ON fm.product_code = dp.product_code  
 WHERE fm.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost))
UNION ALL
(SELECT dp.product_code, dp.product, fm.manufacturing_cost 
 FROM fact_manufacturing_cost fm 
 JOIN dim_product dp ON fm.product_code = dp.product_code  
 WHERE fm.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost));


/* 
6. Generate a report with top 5 customers in India (2021) by average high pre_invoice_discount_pct.
   Output: customer_code, customer, average_discount_percentage
*/

-- Top 5 customers in India (2021) by average pre-invoice discount
SELECT dc.customer, 
       dc.customer_code, 
       ROUND(AVG(fp.pre_invoice_discount_pct) * 100, 2) AS avg_discount_pct  
FROM fact_pre_invoice_deductions fp 
JOIN dim_customer dc ON fp.customer_code = dc.customer_code
WHERE fiscal_year = 2021 AND market = "India"
GROUP BY dc.customer 
ORDER BY avg_discount_pct DESC 
LIMIT 5;


/* 
7. Get gross sales amount for customer “Atliq Exclusive” per month.
   Output: Year, Month, Gross sales Amount
*/

-- Monthly gross sales for "Atliq Exclusive"
SELECT 
    YEAR(date) AS year, 
    MONTH(date) AS month, 
    SUM(sold_quantity * gross_price) AS gross_sales_amount
FROM fact_sales_monthly fs 
JOIN fact_gross_price fp ON fs.product_code = fp.product_code AND fs.fiscal_year = fp.fiscal_year 
JOIN dim_customer dc ON fs.customer_code = dc.customer_code
WHERE customer = "Atliq Exclusive"
GROUP BY year, month 
ORDER BY year, month;


/* 
8. In which quarter of 2020 was the highest sold quantity?
   Output: Quarter, total_sold_quantity (in M)
*/

-- Highest sold quantity quarter in 2020
SELECT CASE 
        WHEN MONTH(date) BETWEEN 9 AND 11 THEN 'Q1'
        WHEN MONTH(date) BETWEEN 12 AND 2 THEN 'Q2'
        WHEN MONTH(date) BETWEEN 3 AND 5 THEN 'Q3'
        WHEN MONTH(date) BETWEEN 6 AND 8 THEN 'Q4' 
       END AS quarter,
       CONCAT(ROUND(SUM(sold_quantity) / 1000000, 2), " M") AS total_sold_quantity
FROM fact_sales_monthly 
WHERE fiscal_year = 2020 
GROUP BY quarter 
ORDER BY total_sold_quantity DESC;


/* 
9. Which channel brought the most gross sales in 2021 and its contribution percentage?
   Output: channel, gross_sales_mln, percentage
*/

-- Top-performing sales channel in 2021 with contribution %
WITH channels AS (
    SELECT channel, 
           (SUM(sold_quantity * gross_price) / 1000000) AS gross_sales_mln
    FROM fact_sales_monthly fm 
    JOIN fact_gross_price fp ON fm.product_code = fp.product_code
    JOIN dim_customer dc ON fm.customer_code = dc.customer_code
    WHERE fm.fiscal_year = 2021 
    GROUP BY channel 
)
SELECT 
    channel, 
    gross_sales_mln, 
    ROUND(gross_sales_mln * 100 / SUM(gross_sales_mln) OVER (), 2) AS pct_contributions 
FROM channels;


/* 
10. Get Top 3 products in each division by total_sold_quantity in 2021.
   Output: division, product_code, product, total_sold_quantity, rank_order
*/

-- Top 3 products per division based on total sold quantity
WITH ranked_products AS (
    WITH top_products AS (
        SELECT fm.product_code, 
               dp.product, 
               dp.division, 
               SUM(sold_quantity) AS total_sold_quantity
        FROM fact_sales_monthly fm 
        JOIN dim_product dp ON fm.product_code = dp.product_code
        WHERE fiscal_year = 2021 
        GROUP BY fm.product_code, dp.division
    )
    SELECT *, 
           RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order 
    FROM top_products
)
SELECT * 
FROM ranked_products 
WHERE rank_order IN (1,2,3);


/* 
11. Identify products sold in 2020 but discontinued in 2021.
   Output: product_code, product, segment, fiscal_year
*/

-- Products sold in 2020 but not in 2021
SELECT DISTINCT dp.product_code, 
       dp.product, 
       dp.segment, 
       fm.fiscal_year  
FROM fact_sales_monthly fm 
JOIN dim_product dp USING (product_code)
WHERE dp.product_code NOT IN (
    SELECT DISTINCT product_code FROM fact_sales_monthly WHERE fiscal_year = 2021
) 
AND fm.fiscal_year = 2020;
