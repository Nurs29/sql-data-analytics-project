-- ADVANCED ANALYTICS PROJECT

--============================
-- 1. Change-Over-Time(Trends)
--============================

/*
	Analyze how a measure evolves over time.

	Helps track trends and identify seasonality in your data.

	AGG[Measure] By [Date Dimension]

	Total Sales By Year
	Average Cos By Month
*/

-- 1. Analyze Sales Performance Over Time. 
-- Year

SELECT
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Changes Over Years: A high-level overview unsights that helps with strategic decision-making.

-- Month

SELECT
	YEAR(order_date) AS order_year,
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- OR 

SELECT
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date);

-- OR

SELECT
	FORMAT(order_date, 'yyyy-MMM') AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');
-- But here, months does not sorted, beacause it's string.


--=======================
-- 2. Cumulative Analysis
--=======================

/*
	Aggregate the data progressively over time.

	Helps to understand whether our business is growing or declining.

	AGG[Cumulative Measure] By [Date Dimension]

	Running Total Sales By Year
	MovingAverage of Sales By Month
*/

-- 1. Calculate the total sales per month and the running total of sales over time. 

SELECT
	t.order_date,
	t.total_sales,
	SUM(t.total_sales) OVER (PARTITION BY YEAR(t.order_date) ORDER BY t.order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_sales,
	AVG(t.average_price) OVER (ORDER BY t.order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS moving_average_price
FROM (
	SELECT
		DATETRUNC(MONTH, order_date) AS order_date,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS average_price
	FROM gold.fact_sales
	WHERE DATETRUNC(MONTH, order_date) IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date) 
)t;

/*
	What is the difference between using a Normal Aggreagation and Cumulative Aggregation?

	We usually use a Normal Aggregations in order to check the performance of each individual role. How each year is performing, I'm going to do a normal aggregation.
	But if you want to see a progression and you want to understand how your business is growing you have to go and use cumulative aggregation, because you can see 
	easily here the progress of your business ovr the time. 
*/


--========================
-- 3. Performance Analysis
--========================

/*
	Comparing the current value to target value.

	Helps measure success and compare performance.

	Current[Measure] - Target[Measure]

	Current Sales - Average Sales
	Current Year Sales - Previous Year Sales <- YoY Analysis
	Current Sales - Lowest Sales
*/

-- 1. Analyze the yearly performance of products by comparing each product's sales to both it's average sales performance and the previous year's sales.

WITH yearly_product_sales AS (
SELECT
	YEAR(f.order_date) AS order_year,
	p.product_name,
	SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE YEAR(f.order_date) IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)
SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE
		WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
		WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
		ELSE 'Avg'
	END AS avg_change,
	-- Year-over-Year Analysis
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS previous_year_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_previous_year,
	CASE
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		ELSE 'No Change'
	END AS previous_year_change
FROM yearly_product_sales
ORDER BY product_name, order_year;


--==========================
-- 4. Part-To-Whole Analysis
--==========================

/*
	Analyze how an individual part is performing compared to the overall, allowing us to understand
	which category has the greates impact on the business.

	([Measure] / Total[Measure]) * 100 By [Dimension]
	(Sales / Total Sales) * 100 By Category
*/

-- 1. Which categories contribute the most overall sales

WITH category_sales AS (
SELECT
	p.category,
	SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
GROUP BY p.category
)

SELECT
	category,
	total_sales,
	SUM(total_sales) OVER() AS overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) *100, 2), '%') percentage_of_total
FROM category_sales
ORDER BY percentage_of_total DESC;


--=====================
-- 5. Data Segmentation
--=====================

/*
	Group the data based on a specific range.

	Help to understand the correlation between two measures.

	[Measure] By [Measure]
	Total Products By Sales Range
	Total Customers By Age
*/

-- 1. Segment products into cost ranges and count how many products fall ito each segment.

WITH product_segments AS (
SELECT
	product_key,
	product_name,
	cost,
	CASE	
		WHEN cost < 100 THEN 'Below 100'
		WHEN cost BETWEEN 100 AND 500 THEN '100-500'
		WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
		ELSE 'Above 1000'
	END cost_range
FROM gold.dim_products
)
SELECT
	cost_range,
	COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

/*
	2. Group cusomers into three segments based on their spending behavior:
			- VIP: at least 12 months of history and spending more than $5.000.
			- Regular: at least 12 months of hisory but spending $5.000 or less.
			- New: lifespan less than 12 months.
		And fing the total number of customers by each group.
*/

WITH customer_spending AS (
SELECT
	c.customer_key,
	SUM(f.sales_amount) AS total_spending,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT 
	customer_key,
	lifespan,
	CASE	
		WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
		ELSE 'New Customer'
	END customer_segment
FROM customer_spending;

-----------------------------------------------------------------------------------------


WITH customer_spending AS (
SELECT
	c.customer_key,
	SUM(f.sales_amount) AS total_spending,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT
	customer_segment,
	COUNT(customer_key) AS total_customers
FROM (
	SELECT 
		customer_key,
		lifespan,
		CASE	
			WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
			WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
			ELSE 'New Customer'
		END customer_segment
	FROM customer_spending
)t
GROUP BY customer_segment
ORDER BY total_customers DESC;


--===================
-- 6. Customer Report
--===================

/*
	Purpose: 
		- This report consolidates key customer metrics and behaviors

	Highlights:
		1. Gathers essential fields such as names, ages and transaction details.
		2. Segments customers into categories (VIP, Regular, New) ana age groups.
		3. Aggregates customer-level metrics:
			- total orders
			- total sales
			- total quantity purchased
			- total products
			- lifespan (in months)
		4. Calculates valuable KPIs:
			- recency (months since last order)
			- average order value
			- average monthly spend
*/

CREATE VIEW gold.report_customers AS
WITH base_query AS (
/*------------------------------------------------------------
	1. Base Query: Retrieve core columns from tables
------------------------------------------------------------*/
SELECT
	f.order_number,
	f.product_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
	DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL
)

, customer_aggregation AS (
/*----------------------------------------------------------------------------
	2. Customer Aggregations: Summarizes key metrics at the customer level
----------------------------------------------------------------------------*/
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(product_key) AS total_products,
	MAX(order_date) AS last_order_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	customer_name,
	age
)

SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE 
		WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN '20-29'
		WHEN age BETWEEN 30 AND 39 THEN '30-39'
		WHEN age BETWEEN 40 AND 49 THEN '40-49'
		ELSE '50 and above'
	END AS age_group,

	CASE	
		WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END customer_segment,
	last_order_date,
	DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_quantity,
	lifespan,
	-- Compute average order value (AVO)
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	 END AS avg_order_value,
	 -- Compute average monthly spend
	 CASE	
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_spend
FROM customer_aggregation;


--FINAL REPORT
SELECT * FROM gold.report_customers;

SELECT
	age_group,
	COUNT(customer_number) AS total_customer,
	SUM(total_sales) AS total_sales
FROM gold.report_customers
GROUP BY age_group;


--==================
-- 7. Product Report
--==================

/*
	Purpose: 
		- This report consolidates key product metrics and behaviors

	Highlights:
		1. Gathers essential fields such as product name, category, subcategory and cost.
		2. Segments products by revenue to identify High-Performers, Mid-range or Low-Performes.
		3. Aggregates product-level metrics:
			- total orders
			- total sales
			- total quantity sold
			- total customers (unique)
			- lifespan (in months)
		4. Calculates valuable KPIs:
			- recency (months since last sale)
			- average order revenue (AOR)
			- average monthly revenue
*/


CREATE VIEW gold.report_products AS
WITH base_query AS (
/*-------------------------------------------------------------------------------------
	1. Base Query: Retrieves core columns from facts_sales and dim_products
-------------------------------------------------------------------------------------*/
SELECT
	f.order_number,
	f.order_date,
	f.customer_key,
	f.sales_amount,
	f.quantity,
	p.product_key,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE order_date IS NOT NULL -- only consider valid sales dates.
)

, product_aggregations AS (
/*-----------------------------------------------------------------------------
	2. Product Aggregations: Summarizes key metrics at the product level
-----------------------------------------------------------------------------*/
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	MAX(order_date) AS last_sale_date,
	COUNT(DISTINCT order_number) AS total_orders,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
FROM base_query
GROUP BY 
	product_key,
	product_name,
	category,
	subcategory,
	cost
)

/*----------------------------------------------------------------------
	3. Final Query: Combines all product results into one output
----------------------------------------------------------------------*/
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_months,
	CASE
		WHEN total_sales >= 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END as product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue (AOR)
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,

	-- Average Monthly Revenue
	CASE	
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue
FROM product_aggregations;

--FINAL REPORT
SELECT * FROM gold.report_products;
