--EXPLORATORY DATA ANALYSIS

--====================
-- 1. Data Exploration
--====================

-- Explore All Objects in the Database
SELECT
	*
FROM INFORMATION_SCHEMA.TABLES;


-- Explore All Columns in the Database
SELECT
	*
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';

---------------------------------------------------------

--=========================
-- 2. Dimension Exploration
--=========================

/*
	Identifying the unique values (or categories) in each dimesnion.

	Recognizing how data might be grouped or segmented, which is useful for later analysis.

	DISTINCT[Dimension]
*/

-- 1. Explore all countries our customers come from.

SELECT
	DISTINCT country
FROM gold.dim_customers;

-- 2. Explore All Product Categories 'The Major Divisions'.

SELECT
	DISTINCT category, 
	subcategory, 
	product_name
FROM gold.dim_products
ORDER BY 1, 2, 3;

---------------------------------------------------------

--====================
-- 3. Date Exploration
--====================

/*
	Identify the earliest and latest dates (boundries).

	Understand the scope of data and the timespan (промежуток времени).

	MIN/MAX[Date Dimensions]
*/

-- 1. Find the date of the first and last order.

SELECT
	MIN(order_date) AS first_order_date,
	MAX(order_date) AS last_order_date
FROM gold.fact_sales;

-- 2. How many years of sales are available

SELECT
	MIN(order_date) AS first_order_date,
	MAX(order_date) AS last_order_date,
	DATEDIFF(YEAR, MIN(order_date), MAX(order_date)) AS order_range_years,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;

-- 3. Find the youngest and oldest customer.

SELECT
	MIN(birthdate) AS oldest_birthdate,
	DATEDIFF(YEAR, MIN(birthdate), GETDATE()) AS oldest_age,
	MAX(birthdate) AS youngest_birthdate,
	DATEDIFF(YEAR, MAX(birthdate), GETDATE())  AS youngest_age
FROM gold.dim_customers;

---------------------------------------------------------

--======================================
-- 4. Measures Exploration (Big Numbers)
--======================================

/*
	Calculate the key metric of the business (Big Numbers).

	- Highest Level of Aggregation | Lowest Level of Details - 

	SUM[Measure], AVG[Measure], COUNT[Measure]
*/

-- 1. Find the Total Sales

SELECT
	SUM(sales_amount) AS total_sales
FROM gold.fact_sales;

-- 2. Find How Many Items are sold

SELECT
	SUM(quantity) AS total_quantity
FROM gold.fact_sales;

-- 3. Find the Average selling price

SELECT
	AVG(price) AS average_price
FROM gold.fact_sales;

-- 4. Find the Total number of Orders

SELECT
	COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales;

-- 5. Find the Total number of Products

SELECT
	COUNT(DISTINCT(product_name)) AS total_products
FROM gold.dim_products;

-- 6. Find the Total number of Customers

SELECT
	COUNT(customer_id) AS total_customers
FROM gold.dim_customers;

-- 7. Find the Total number of customers that has placed an order

SELECT
	COUNT(DISTINCT customer_key)
FROM gold.fact_sales;

-- 8. Generate a Report that shows all key metrics of the business

SELECT
	'Total Sales' AS measure_name,
	SUM(sales_amount) AS measure_value
FROM gold.fact_sales
UNION ALL 
SELECT
	'Total Quantity',
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
UNION ALL
SELECT
	'Average Price',
	AVG(price) AS average_price
FROM gold.fact_sales
UNION ALL
SELECT
	'Total Nr. Orders',
	COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales
UNION ALL
SELECT
	'Total Nr. Products',
	COUNT(DISTINCT(product_name)) AS total_products
FROM gold.dim_products
UNION ALL
SELECT
	'Total Nr. Customers',
	COUNT(customer_id) AS total_customers
FROM gold.dim_customers
UNION ALL
SELECT
	'Customers That Ordered',
	COUNT(DISTINCT customer_key)
FROM gold.fact_sales;

---------------------------------------------------------

--========================================
-- 5. Magnitude Analysis (Анализ величины)
--========================================

/*
	Compare the measure values by categories.

	It helps us understand the importance of different categories.

	AGG[Measure] By [Dimension]
	Total Sales By Country, 
	Average Price By Product, etc.
*/

-- 1. Find total customers by countries

SELECT
	country,
	COUNT(customer_id) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- 2. Find total customers by gender

SELECT
	gender,
	COUNT(customer_id)  AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;

-- 3. Find total products by category

SELECT
	category,
	COUNT(product_id) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- 4. What is the average costs in each category?

SELECT
	category,
	AVG(cost) AS average_cost
FROM gold.dim_products
GROUP BY category
ORDER BY average_cost DESC;

-- 5. What is the total revenue generated for each category?

SELECT
	pr.category,
	SUM(fs.sales_amount) AS total_revenue	
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products pr
ON fs.product_key = pr.product_key
GROUP BY pr.category
ORDER BY total_revenue DESC;

-- 6. Find the revenue is generated by each customer

SELECT 
	cu.customer_key,
	cu.first_name,
	cu.last_name,
	SUM(fs.sales_amount) total_revenue
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers cu
ON fs.customer_key = cu.customer_key
GROUP BY cu.customer_key, cu.first_name, cu.last_name
ORDER BY total_revenue DESC;

-- 7. What is the distribution of sold items across countries?

SELECT
	cu.country,
	SUM(fs.quantity) AS total_sold_items
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers cu
ON fs.customer_key = cu.customer_key
GROUP BY cu.country
ORDER BY total_sold_items DESC;

---------------------------------------------------------

--==============================
-- 6. Ranking. Topn N / Bottom N
--==============================

/*
	Order the values of dimensions by measure.

	Topp N Performers | Bottom N Performers

	RANK[Dimension] BY AGG[Measure]
	Rank Countries By Total Sales
	TOP 5 Products By Quantity
	BOTTOM 3 Customers By Total Orders
*/

-- 1. Which 5 products generate the highest revenue? 

SELECT TOP 5
	pr.product_name,
	SUM(fs.sales_amount) AS total_revenue	
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products pr
ON fs.product_key = pr.product_key
GROUP BY pr.product_name
ORDER BY total_revenue DESC;

-------------------------------------

SELECT 
	*
FROM (
	SELECT
		pr.product_name,
		SUM(fs.sales_amount) AS total_revenue,
		RANK() OVER(ORDER BY SUM(fs.sales_amount) DESC) AS rank_products
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_products pr
	ON fs.product_key = pr.product_key
	GROUP BY pr.product_name) t
WHERE rank_products <= 5;

-- 2. What are the 5 worst-performing products in terms of sales?

SELECT TOP 5
	pr.product_name,
	SUM(fs.sales_amount) AS total_revenue	
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products pr
ON fs.product_key = pr.product_key
GROUP BY pr.product_name
ORDER BY total_revenue ASC;

-- 3. Find the top 10 customers who have generated the highest revenue

SELECT TOP 10
	cu.customer_key,
	cu.first_name,
	cu.last_name,
	SUM(fs.sales_amount) AS total_revenue
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers cu
ON fs.customer_key = cu.customer_key
GROUP BY cu.customer_key, cu.first_name, cu.last_name
ORDER BY total_revenue DESC;

-- 4. The 3 customers with the fewest orders placed

SELECT TOP 3
	cu.customer_key,
	cu.first_name,
	cu.last_name,
	COUNT(DISTINCT fs.order_number) AS total_orders
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers cu
ON fs.customer_key = cu.customer_key
GROUP BY cu.customer_key, cu.first_name, cu.last_name
ORDER BY total_orders ASC;




