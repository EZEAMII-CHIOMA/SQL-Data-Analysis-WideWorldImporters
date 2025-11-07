/*----BEGINNER LEVEL — Data Exploration & Descriptive Analysis

Goal:  Get familiar with retrieving, summarizing, and filtering data.
---1. Total revenue generated monthly, quartery, and yearly. -------------
---2. Total number of orders placed per month.
---3. Total number of customers who placed orders.
---5. Top products by sales revenue.
---6. Periods with lowest and highest sales volume in 2015
---7. Total tax collected per year.
---8. Number of completed vs pending orders per year
---9. Total quantity sold per product.
---10. Total sales by stateProvince .
---11. Total sales by City .
---12. Top 10 customers by total spending.
---13. Customers with the highest number of orders.
---14. New customers acquired per month.
---15. Top products by sales revenue.
---16. Customer count per State/province
---17. Total revenue per customer segment.
---18. Products selling the most (by quantity and revenue).
---19. Quantity of products sold this 2014 vs last 2015.
---20. Distinct products sold each year.
---21. Average selling price per product.
---22. Products not sold in 2016.
---23. Orders processed per day on average.
---24. Orders processed per week on average.
---25. Total stock on hand vs reorder level.
---26. Stock movement trends .
---27. Vehicles with recorded temperature readings (from `VehicleTemperatures`).
*/

----Sales Metrics 
-------1. Total revenue generated monthly, quartery, and yearly. -------------

-- Monthly Revenue
SELECT 
    YEAR(b.OrderDate) AS Order_Year,
    DATENAME(MONTH, b.OrderDate) AS Order_Month,
    SUM(a.pickedQuantity * a.UnitPrice) AS Total_Revenue
FROM Sales.OrderLines a
JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY YEAR(b.OrderDate), MONTH(b.OrderDate), DATENAME(MONTH, b.OrderDate)
ORDER BY YEAR(b.OrderDate), MONTH(b.OrderDate);


--  Quarterly Revenue
SELECT 
    YEAR(b.OrderDate) AS Order_Year,
    DATEPART(QUARTER, b.OrderDate) AS Order_Quarter,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue
FROM Sales.OrderLines a
JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY YEAR(b.OrderDate), DATEPART(QUARTER, b.OrderDate)
ORDER BY YEAR(b.OrderDate), DATEPART(QUARTER, b.OrderDate);


-- Yearly Revenue
SELECT 
    YEAR(b.OrderDate) AS Year_,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue
FROM Sales.OrderLines a
JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY YEAR(b.OrderDate)
ORDER BY YEAR(b.OrderDate);

---2. Total number of orders placed per month.
SELECT 
	YEAR(Orderdate) Order_Year,
	DATENAME(MONTH,Orderdate) Order_Month,
	COUNT(DISTINCT a.orderid) Total_Distinct_Orders,
	COUNT(a.orderid) Total_Orders
FROM Sales.OrderLines a
JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY YEAR(OrderDate),Month(OrderDate),DATENAME(MONTH,Orderdate)
ORDER BY YEAR(OrderDate),Month(OrderDate)

---3. Total number of customers who placed orders.
SELECT 
	COUNT(DISTINCT CustomerID) Total_Customers_Who_Placed_Orders
FROM Sales.Orders

---4. Average order value .(Average of the total amount of each order.)
SELECT AVG(Total_Revenue) Avg_Order_Value
FROM (
	SELECT 
	a.OrderID,
	SUM(a.PickedQuantity * a.UnitPrice) Total_Revenue
	FROM Sales.OrderLines a
	JOIN Sales.Orders b ON a.OrderID = b.OrderID
	GROUP BY a.OrderID
	)t;

---5. Top products by sales revenue.
SELECT 
	TOP 10 StockItemName AS ProductName, 
	SUM(PickedQuantity * a.UnitPrice) Total_Revenue
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
GROUP BY StockItemName
ORDER BY Total_Revenue DESC

---6. Periods with lowest and highest sales volume in 2015
SELECT MonthPeriod, Total_Revenue, 'Lowest' AS PeriodType
FROM(
	SELECT TOP 1
		DATENAME(MONTH,Orderdate) MonthPeriod,
		SUM(PickedQuantity * unitprice) Total_Revenue
	FROM Sales.OrderLines a
	LEFT JOIN Sales.Orders b ON a.orderid = b.orderid
	WHERE Year(Orderdate) = '2015' 
	GROUP BY DATENAME(MONTH,Orderdate)
	ORDER BY Total_Revenue ASC
) AS Lowest
UNION ALL
SELECT MonthPeriod, Total_Revenue, 'Highest' AS PeriodType
FROM(
	SELECT TOP 1
		DATENAME(MONTH,Orderdate) MonthPeriod,
		SUM(PickedQuantity * unitprice) Total_Revenue
	FROM Sales.OrderLines a
	LEFT JOIN Sales.Orders b ON a.orderid = b.orderid
	WHERE Year(Orderdate) = '2015'
	GROUP BY DATENAME(MONTH,Orderdate)
	ORDER BY Total_Revenue DESC
) AS Highest


---7. Total tax collected per year.
SELECT 
	YEAR(Orderdate) TaxYear,
	SUM(Pickedquantity * unitprice * (taxrate/100)) Total_Tax
FROM Sales.Orderlines a
LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY YEAR(Orderdate)


---8. Number of completed vs pending orders per year

SELECT 
    YEAR(b.OrderDate) AS Order_Year,
    SUM(CASE 
            WHEN b.PickingCompletedWhen IS NULL THEN 1 
            ELSE 0 
        END) AS Pending_Orders,
    SUM(CASE 
            WHEN b.PickingCompletedWhen IS NOT NULL THEN 1 
            ELSE 0 
        END) AS Completed_Orders
FROM Sales.Orders b
GROUP BY YEAR(b.OrderDate)
ORDER BY YEAR(b.OrderDate);

---9. Total quantity sold per product.
SELECT StockItemName AS ProductName,
	SUM(Pickedquantity) Total_Quantity
FROM Sales.OrderLines a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
GROUP BY StockItemName 

---10. Total sales by stateProvince .

SELECT 
    e.StateProvinceName,
    SUM(a.Quantity * a.UnitPrice) AS Total_Sales
FROM Sales.OrderLines AS a
JOIN Sales.Orders AS b ON a.OrderID = b.OrderID
JOIN Sales.Customers AS c ON b.CustomerID = c.CustomerID
JOIN Application.Cities AS d ON c.DeliveryCityID = d.CityID
JOIN Application.StateProvinces AS e ON d.StateProvinceID = e.StateProvinceID
GROUP BY e.StateProvinceName
ORDER BY Total_Sales DESC


---11. Total sales by City .

SELECT 
    d.CityName,
    SUM(a.Quantity * a.UnitPrice) AS Total_Sales
FROM Sales.OrderLines AS a
JOIN Sales.Orders AS b ON a.OrderID = b.OrderID
JOIN Sales.Customers AS c ON b.CustomerID = c.CustomerID
JOIN Application.Cities AS d ON c.DeliveryCityID = d.CityID
GROUP BY d.CityName
ORDER BY Total_Sales DESC


-----Customer Basics ------

---12. Top 10 customers by total spending.
SELECT TOP 10
	a.CustomerID,
	Customername,
	CASE 
		WHEN CHARINDEX(' (', CustomerName) > 0 
		THEN LEFT(CustomerName, CHARINDEX(' (', CustomerName) - 1)
		ELSE RTRIM(CustomerName)
	END AS Company_Name,
	SUM(PickedQuantity * unitprice) Total_Spending
FROM Sales.Customers a
LEFT JOIN Sales.Orders b ON a.customerid = b.customerid
LEFT JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
GROUP BY 	a.CustomerID,Customername
ORDER BY Total_Spending DESC

---13. Customers with the highest number of orders.
SELECT TOP 10
	a.Customerid,
	CustomerName,
	CASE 
		WHEN CHARINDEX( ' (', CustomerName) > 0
		THEN LEFT(CustomerName, CHARINDEX( ' (', CustomerName) - 1)
		ELSE RTRIM(Customername)
	END AS Company_Name,
    COUNT(DISTINCT b.OrderID) AS Number_of_Orders
FROM Sales.Customers a
LEFT JOIN Sales.Orders b ON a.customerid = b.customerid
GROUP BY a.Customerid,CustomerName
ORDER BY Number_of_Orders DESC


---14. New customers acquired per month.

WITH FirstOrders AS (
    SELECT 
        CustomerID,
        MIN(OrderDate) AS FirstOrderDate
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT 
    YEAR(FirstOrderDate) AS Order_Year,
	MONTH(FirstOrderDate) AS Order_Month_Number,
    DATENAME(MONTH, FirstOrderDate) AS Order_Month,
    COUNT(*) AS Number_Of_New_Customers
FROM FirstOrders
GROUP BY YEAR(FirstOrderDate), MONTH(FirstOrderDate), DATENAME(MONTH, FirstOrderDate)
ORDER BY YEAR(FirstOrderDate), MONTH(FirstOrderDate);

---15. Customers with repeat vs one-time purchases.
WITH Purchases AS(
SELECT 
	Customerid,
	COUNT( DISTINCT a.orderid) Number_of_Orders
FROM sales.orderlines a
LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY CustomerID
)
SELECT 
	Customerid,
	CASE WHEN  Number_of_Orders > 1 
		 THEN 'Repeat_Purchases' 
		 ELSE 'One_Time_Purchase'
	END AS Number_of_purchase
FROM Purchases

---16. Customer count per State/province

SELECT 
    e.StateProvinceName,
    COUNT(Distinct b.CustomerID) AS Total_customers
FROM Sales.OrderLines AS a
JOIN Sales.Orders AS b ON a.OrderID = b.OrderID
JOIN Sales.Customers AS c ON b.CustomerID = c.CustomerID
JOIN Application.Cities AS d ON c.DeliveryCityID = d.CityID
JOIN Application.StateProvinces AS e ON d.StateProvinceID = e.StateProvinceID
GROUP BY e.StateProvinceName
ORDER BY Total_customers DESC

---17. Total revenue per customer segment.

SELECT 
	CustomerCategoryName,
	SUM(Pickedquantity * unitprice) Total_Revenue
FROM Sales.Customers a
LEFT JOIN Sales.CustomerCategories b ON a.CustomerCategoryID = b.CustomerCategoryID
LEFT JOIN Sales.Orders c ON a.CustomerID = c.CustomerID
LEFT JOIN Sales.OrderLines d ON c.OrderID = d.OrderID
GROUP BY CustomerCategoryName

---Product & Inventory Basics
---18. Products selling the most (by quantity and revenue).
SELECT 
	stockitemname,
	SUM(Pickedquantity) Quantity_Sold,
	SUM(Pickedquantity * b.Unitprice) Total_Revenue
FROM Sales.OrderLines a
JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
GROUP BY StockItemName
ORDER BY Quantity_Sold DESC


---19. Quantity of products sold this 2014 vs last 2015.
WITH ProductSales AS (
    SELECT 
        b.StockItemName,
        YEAR(c.OrderDate) AS OrderYear,
        SUM(a.PickedQuantity) AS QuantitySold
    FROM Sales.OrderLines a
    JOIN Warehouse.StockItems b 
        ON a.StockItemID = b.StockItemID
    JOIN Sales.Orders c 
        ON a.OrderID = c.OrderID
    WHERE YEAR(c.OrderDate) IN (2014, 2015)
    GROUP BY b.StockItemName, YEAR(c.OrderDate)
)
SELECT 
    StockItemName,
    SUM(CASE WHEN OrderYear = 2014 THEN QuantitySold ELSE 0 END) AS Quantity_2014,
    SUM(CASE WHEN OrderYear = 2015 THEN QuantitySold ELSE 0 END) AS Quantity_2015,
    SUM(CASE WHEN OrderYear = 2015 THEN QuantitySold ELSE 0 END)
    - SUM(CASE WHEN OrderYear = 2014 THEN QuantitySold ELSE 0 END) AS Diff,
    CASE 
        WHEN SUM(CASE WHEN OrderYear = 2015 THEN QuantitySold ELSE 0 END)
             - SUM(CASE WHEN OrderYear = 2014 THEN QuantitySold ELSE 0 END) > 0 THEN 'Increase'
        WHEN SUM(CASE WHEN OrderYear = 2015 THEN QuantitySold ELSE 0 END)
             - SUM(CASE WHEN OrderYear = 2014 THEN QuantitySold ELSE 0 END) = 0 THEN 'No Change'
        ELSE 'Decrease'
    END AS Category
FROM ProductSales
GROUP BY StockItemName
ORDER BY Diff DESC;

---20. Distinct products sold each year.

SELECT 
    YEAR(b.OrderDate) AS OrderYear,
    COUNT(DISTINCT a.StockItemID) AS DistinctProducts
FROM Sales.OrderLines a
JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY YEAR(b.OrderDate)
ORDER BY OrderYear;

---21. Average selling price per product.

SELECT 
    b.StockItemName,
    AVG(a.UnitPrice) AS Avg_Selling_Price
FROM Sales.OrderLines a
JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
GROUP BY b.StockItemName
ORDER BY Avg_Selling_Price DESC;

--- 22. Products not sold in 2016.

SELECT 
    a.StockItemName
FROM Warehouse.StockItems a
WHERE a.StockItemID NOT IN (
    SELECT DISTINCT a.StockItemID
    FROM Sales.OrderLines a
    JOIN Sales.Orders b ON a.OrderID = b.OrderID
    WHERE YEAR(b.OrderDate) = 2016
)
ORDER BY a.StockItemName;


---Operational & Regional Basics
---23. Orders processed per day on average.
SELECT 
	AVG(Total_orders) AVG_Orders_Per_Day
FROM(
	SELECT
		Orderdate,
		COUNT(DISTINCT a.Orderid)Total_orders
	FROM Sales.OrderLines a
	LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
	GROUP BY orderdate
	)DailyCounts

---24. Orders processed per week on average.
SELECT 
    AVG(WeeklyOrderCount) AS Avg_Orders_Per_Week
FROM (
    SELECT 
        DATEPART(YEAR, OrderDate) AS OrderYear,
        DATEPART(WEEK, OrderDate) AS OrderWeek,
        COUNT(DISTINCT OrderID) AS WeeklyOrderCount
    FROM Sales.Orders
    GROUP BY DATEPART(YEAR, OrderDate), DATEPART(WEEK, OrderDate)
) AS WeeklyCounts;


---25. Total stock on hand vs reorder level.
SELECT 
	Stockitemid,
	Quantityonhand,
	Reorderlevel,
	(QuantityOnHand - Reorderlevel) AS StockDifference,
	CASE
		WHEN QuantityOnHand > ReorderLevel THEN 'NO'
		WHEN QuantityOnHand < ReorderLevel THEN 'YES'
	END Needs_Reorder
FROM Warehouse.StockItemHoldings

---26. Stock movement trends .
SELECT 
	StockItemID,
	YEAR(TransactionOccurredWhen) AS Year,
	SUM(CASE WHEN Quantity > 0 THEN Quantity ELSE 0 END) AS StockIn,
    SUM(CASE WHEN Quantity < 0 THEN ABS(Quantity) ELSE 0 END) AS StockOut,
    SUM(Quantity) AS NetMovement
FROM Warehouse.StockItemTransactions
GROUP BY StockItemID,YEAR(TransactionOccurredWhen)
ORDER BY Year

---27. Vehicles with recorded temperature readings.
SELECT DISTINCT VehicleRegistration,
	MIN(Recordedwhen) FirstReading ,
	MAX(Recordedwhen) LastReading
FROM Warehouse.VehicleTemperatures
GROUP BY VehicleRegistration





























