

--DAwSQL Session -8 

--E-Commerce Project Solution


--1. Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)
SELECT a.*,b.Sales,b.Discount,b.Order_Quantity,b.Product_Base_Margin,c.*,d.* , e.* 
INTO dbo.combined_table
FROM dbo.cust_dimen a ,dbo.market_fact b, dbo.orders_dimen c , dbo.prod_dimen d , dbo.shipping_dimen e 
where a.Cust_id =b.Cust_id and  b.Ord_id = c.Ord_id and b.Prod_id = d.Prod_id and b.Ship_id=e.Ship_id

select * 
from dbo.combined_table


--///////////////////////


--2. Find the top 3 customers who have the maximum count of orders.
SELECT top (3) Cust_id, count(Ord_id) as  total_order
FROM  combined_table
group by Cust_id
order by total_order desc ; 


--/////////////////////////////////



--3.Create a new column at combined_table as DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.
--Use "ALTER TABLE", "UPDATE" etc.
ALTER TABLE combined_table
ADD DaysTakenForDelivery INT ; 

UPDATE combined_table
SET DaysTakenForDelivery = DATEDIFF(DAY,Order_Date,Ship_Date);




--////////////////////////////////////


--4. Find the customer whose order took the maximum time to get delivered.
--Use "MAX" or "TOP"
SELECT top 1 Customer_Name 
FROM combined_table
order by DaysTakenForDelivery desc ;


--////////////////////////////////



--5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
--You can use date functions and subqueries

-- Total number of unique customers in January
SELECT COUNT(distinct Cust_id)
from combined_table
where MONTH (Order_Date) = 1  
AND YEAR(Order_Date) = 2011;

-- Total number of customers who came back every month over the entire year in 2011.
SELECT COUNT(Cust_id) 
from combined_table
where YEAR(Order_Date) = 2011
group by Cust_id 
having count(distinct DATEPART(MONTH,Order_Date))= 12;






--////////////////////////////////////////////


--6. write a query to return for each user acording to the time elapsed between the first purchasing and the third purchasing, 
--in ascending order by Customer ID
--Use "MIN" with Window Functions
WITH TAB1 AS (
  SELECT Cust_id,Ord_id,Order_Date,
		MIN (Order_Date) OVER (PARTITION BY Cust_id) first_order_date,
		DENSE_RANK () OVER (PARTITION BY Cust_id ORDER BY Order_Date) as row_num
  FROM combined_table
  )
SELECT distinct Cust_id,first_order_date,Order_Date as third_order_date,DATEDIFF(day,first_order_date,Order_Date) as day_diff 
FROM TAB1
where row_num = 3    
order by Cust_id ASC;




--//////////////////////////////////////

--7. Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratio of these products to the total number of products purchased by all customers.
--Use CASE Expression, CTE, CAST and/or Aggregate Functions

WITH tab1 as (
Select Cust_id ,
		SUM(CASE WHEN Prod_id = 'Prod_11' THEN Order_Quantity else 0 end) sum_prod11,
		SUM(CASE WHEN Prod_id = 'Prod_14' THEN Order_Quantity else 0 end) sum_prod14,
		SUM (Order_Quantity) sum_prod
FROM combined_table
group by Cust_id
having SUM(CASE WHEN Prod_id = 'Prod_11' THEN Order_Quantity else 0 end) >=1
		and SUM(CASE WHEN Prod_id = 'Prod_14' THEN Order_Quantity else 0 end) >=1
		)
SELECT Cust_id,
		FORMAT(1.0*sum_prod11/sum_prod,'N2') AS ratýo_p11,	
		--CAST (1.0*sum_prod11/ sum_prod AS NUMERIC (3,2)) AS ratýo_p11,
		FORMAT(1.0*sum_prod14/sum_prod,'N2') as ratýo_p14
		-- CAST (1.0*sum_prod14/ sum_prod AS NUMERIC (3,2)) AS ratýo_p14
FROM tab1;



--/////////////////



--CUSTOMER SEGMENTATION



--1. Create a view that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)
--Use such date functions. Don't forget to call up columns you might need later.

CREATE VIEW customer_log as 
SELECT Cust_id as cust_id, Order_Date,YEAR(Order_Date)as order_date_year, MONTH(Order_Date) as order_date_month
FROM combined_table;


--//////////////////////////////////



  --2.Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning  business)
--Don't forget to call up columns you might need later.
CREATE VIEW num_visit as  
SELECT	cust_id,Order_Date,order_date_year ,order_date_month , COUNT(*) count_visit
FROM	customer_log
GROUP BY cust_id,Order_Date ,order_date_year ,order_date_month;





--//////////////////////////////////


--3. For each visit of customers, create the next month of the visit as a separate column.
--You can order the months using "DENSE_RANK" function.
--then create a new column for each month showing the next month using the order you have made above. (use "LEAD" function.)
--Don't forget to call up columns you might need later.
CREATE VIEW next_month_visit as 
SELECT *,
		LEAD(order_date_month) OVER(PARTITION BY cust_id ORDER BY order_date_year) AS next_month,
		LEAD(Order_Date) OVER (PARTITION BY cust_id order by order_date_year ) next_order_date,
		DENSE_RANK () OVER (PARTITION BY cust_id ORDER BY Order_Date) as row_num
FROM num_visit;



--/////////////////////////////////



--4. Calculate monthly time gap between two consecutive visits by each customer.
--Don't forget to call up columns you might need later.


CREATE VIEW time_gaps AS
SELECT  cust_id,order_date_year,order_date_month,
		DATEDIFF(MONTH , Order_Date,next_order_date) AS next_ord_month_diff 
FROM  next_month_visit ; 






--///////////////////////////////////


--5.Categorise customers using average time gaps. Choose the most fitted labeling model for you.
--For example: 
--Labeled as “churn” if the customer hasn't made another purchase for the months since they made their first purchase.
--Labeled as “regular” if the customer has made a purchase every month.
--Etc.
	
SELECT cust_id, avg_time_gap,
	CASE 
		WHEN avg_time_gap = 1     THEN 'Loyal' 
		WHEN avg_time_gap < 4   and avg_time_gap > 1  THEN 'Little Loyal'
		WHEN avg_time_gap = 4	  THEN 'Regular'
		WHEN avg_time_gap > 4	  THEN 'Iregular'
		WHEN avg_time_gap IS NULL THEN 'Churn'
	END cust_avg_time_gaps
FROM(
	 SELECT cust_id, AVG( next_ord_month_diff ) avg_time_gap
	 FROM  time_gaps
	 GROUP BY cust_id
	) A;






--/////////////////////////////////////




--MONTH-WISE RETENTÝON RATE


--Find month-by-month customer retention rate  since the start of the business.


--1. Find the number of customers retained month-wise. (You can use time gaps)
--Use Time Gaps

WITH tab_1 as(
    select  cust_id as cust_id,
    CASE
        WHEN next_ord_month_diff = 1  THEN 1
        ELSE 0
    END as loyal_cust
    FROM  time_gaps 
   
	)
select sum(loyal_cust) loyal_cust ,count(cust_id) total_cust
from tab_1;




--//////////////////////


--2. Calculate the month-wise retention rate.

--Basic formula: o	Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total Number of Customers in the Current Month

--It is easier to divide the operations into parts rather than in a single ad-hoc query. It is recommended to use View. 
--You can also use CTE or Subquery if you want.

--You should pay attention to the join type and join columns between your views or tables.

WITH tab_1 as(
    select  cust_id as cust_id,
    CASE
        WHEN next_ord_month_diff = 1  THEN 1
        ELSE 0
    END as loyal_cust
    FROM  time_gaps 
   
	)
select sum(loyal_cust) loyal_cust ,count(cust_id) total_cust,
		FORMAT(1.0* sum(loyal_cust) / count(cust_id),'N2') as ratio_cust
from tab_1;






---///////////////////////////////////
--Good luck!