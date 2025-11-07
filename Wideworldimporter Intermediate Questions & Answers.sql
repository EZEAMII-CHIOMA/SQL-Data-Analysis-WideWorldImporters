/*
Focus: GROUP BY, SUM(), COUNT(), AVG(), DATEPART(), simple JOIN`s.

INTERMEDIATE LEVEL — Diagnostic & Comparative Analysis

Goal: Identify patterns, relationships, and reasons behind performance.

Revenue & Growth Analysis

1. Month-over-month revenue growth.
2. Year-over-year revenue growth.
3. Revenue contribution per stock group.
4. Fastest-growing product categories or regions.
5. Seasonal spikes in revenue.
6. Average order value by customer segment.
7. Customers contributing the most to total sales.
8. Products with consistent sales decline.

Customer Behavior & Retention
9. Average time between two purchases by a customer.
10. Active vs inactive customers per quarter.
11. Customers with no purchases in the last 3 months.
12. Repeat purchase rate by region.
13. Percentage of customers accounting for 80% of revenue .
14. One-time buyers vs repeat buyers.

Product & Category Performance
15. Average selling price vs cost per product.
16. Products generating lowest revenue or profit.
17. Profit margin per stock group.
18. Products frequently purchased together .
19. Slow-moving or underperforming products Based on Quantity Sold.
20. Slow-moving or underperforming products Based on Based on Revenue

Operational Efficiency
21. Average order completion time.
22. Ratio of successful to failed transactions.
23. Suppliers with delayed deliveries .
24. Inventory planning improvement opportunities based on sales trends.

Focus: Multiple JOIN`s, CTEs, CASE WHEN, date calculations, correlated subqueries.
*/

---1. Month-over-month revenue growth.
WITH Monthly_Revenue AS (
	SELECT 
		YEAR(Orderdate) Year,
		MONTH(OrderDate) AS Month,
        DATENAME(MONTH, OrderDate) AS MonthName,
		SUM(pickedquantity * UnitPrice) Total_Revenue
	FROM Sales.OrderLines a
	LEFT JOIN Sales.Orders b ON a.orderid = b.orderid
	GROUP BY YEAR(Orderdate),MONTH(Orderdate), DATENAME(MONTH,orderdate)
)
SELECT 
	Year,
	MonthName,
	Total_Revenue,
	LAG(Total_Revenue) OVER (ORDER BY Year, Month) AS Prev_Month_Revenue,
	    CASE 
        WHEN LAG(Total_Revenue) OVER (ORDER BY Year, Month) = 0 THEN NULL
        ELSE 
            ROUND(
                (Total_Revenue - LAG(Total_Revenue) OVER (ORDER BY Year, Month)) * 100.0 /
                LAG(Total_Revenue) OVER (ORDER BY Year, Month),
            2)
    END AS MoM_Growth_Percent
FROM Monthly_Revenue 
ORDER BY Year, Month;

------2. Year-over-year revenue growth.

WITH Yearly_Revenue AS (
	SELECT 
		YEAR(Orderdate) Year,
		SUM(pickedquantity * UnitPrice) Total_Revenue
	FROM Sales.OrderLines a
	LEFT JOIN Sales.Orders b ON a.orderid = b.orderid
	GROUP BY YEAR(Orderdate)
)
SELECT 
	Year,
	Total_Revenue,
	LAG(Total_Revenue) OVER (ORDER BY Year) AS Prev_Year_Revenue,
	    CASE 
        WHEN LAG(Total_Revenue) OVER (ORDER BY Year) = 0 THEN NULL
        ELSE 
            ROUND(
                (Total_Revenue - LAG(Total_Revenue) OVER (ORDER BY Year)) * 100.0 /
                LAG(Total_Revenue) OVER (ORDER BY Year),
            2)
    END AS YoY_Growth_Percent
FROM Yearly_Revenue 
ORDER BY Year

---3. Revenue contribution per stock group.
SELECT 
	c.StockGroupID,
	StockGroupName,
	SUM(Pickedquantity * unitprice) Total_Revenue
FROM Sales.OrderLines a
LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
LEFT JOIN Warehouse.StockItemStockGroups c ON a.StockItemID = c.StockItemID
LEFT JOIN Warehouse.StockGroups d ON c.StockGroupID = d.StockGroupID
GROUP BY c.StockGroupID,StockGroupName
ORDER BY Total_Revenue DESC

---4. Top 5 Fastest-growing States.

WITH State_Revenue AS (
    SELECT
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        DATENAME(MONTH, OrderDate) AS MonthName,
        e.StateProvinceName,
        SUM(PickedQuantity * UnitPrice) AS Total_Revenue
    FROM Sales.OrderLines a
    LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
    JOIN Sales.Customers c ON b.CustomerID = c.CustomerID
    JOIN Application.Cities d ON c.DeliveryCityID = d.CityID
    JOIN Application.StateProvinces e ON d.StateProvinceID = e.StateProvinceID
    GROUP BY e.StateProvinceName, YEAR(OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
),

Region_Growth AS (
    SELECT 
        StateProvinceName,
        Year,
        Month,
        MonthName,
        Total_Revenue,
        LAG(Total_Revenue) OVER (PARTITION BY StateProvinceName ORDER BY Year, Month) AS Prev_Month_Revenue,
        ROUND(
            (Total_Revenue - LAG(Total_Revenue) OVER (PARTITION BY StateProvinceName ORDER BY Year, Month)) * 100.0 /
            NULLIF(LAG(Total_Revenue) OVER (PARTITION BY StateProvinceName ORDER BY Year, Month), 0),
        2) AS MoM_Growth
    FROM State_Revenue
)
SELECT TOP 5
    StateProvinceName,
    Year,
    MonthName,
    Total_Revenue,
    Prev_Month_Revenue,
    MoM_Growth
FROM Region_Growth
WHERE MoM_Growth IS NOT NULL
ORDER BY MoM_Growth DESC;

---5. Seasonal spikes in revenue.

SELECT
    MONTH(OrderDate) AS MonthNumber,
    DATENAME(MONTH, OrderDate) AS MonthName,
    SUM(PickedQuantity * UnitPrice) AS Total_Revenue
FROM Sales.OrderLines a
JOIN Sales.Orders b ON a.OrderID = b.OrderID
GROUP BY MONTH(OrderDate), DATENAME(MONTH, OrderDate)
ORDER BY Total_Revenue DESC;

---6. Average order value by customer segment.
SELECT 
    b.CustomerCategoryName,
	CAST(SUM(d.PickedQuantity * d.UnitPrice) AS FLOAT) / COUNT(DISTINCT c.OrderID)Avg_Order_Value
FROM Sales.Customers a
LEFT JOIN Sales.CustomerCategories b ON a.CustomerCategoryID = b.CustomerCategoryID
LEFT JOIN Sales.Orders c ON a.CustomerID = c.CustomerID
LEFT JOIN Sales.OrderLines d ON c.OrderID = d.OrderID
GROUP BY b.CustomerCategoryName
ORDER BY Avg_Order_Value DESC;

---7. Customers contributing the most to total sales.
SELECT TOP 10
	a.CustomerID,
	CASE 
		WHEN CHARINDEX( '(', Customername) > 0 
		THEN LEFT (customername,CHARINDEX( '(', Customername) -1) 
		ELSE RTRIM(CustomerName) 
	END AS Company_name,
	SUM(Pickedquantity * unitprice) Total_Revenue
FROM Sales.Customers a
LEFT JOIN Sales.Orders b ON a.CustomerID = b.CustomerID
LEFT JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
GROUP BY 	a.CustomerID,CustomerName
ORDER BY Total_Revenue DESC

---8. Products with consistent sales decline.
WITH Monthly_sales AS(
	SELECT 
		Description AS Product,
		YEAR(Orderdate) SaleYear,
		MONTH(OrderDate) SaleMonth,
		SUM(Pickedquantity * Unitprice) Total_Revenue
	FROM Sales.OrderLines a
	LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
	GROUP BY Description,YEAR(OrderDate),MONTH(Orderdate)
),
Sales_with_change AS (
	SELECT 
		Product,
		Saleyear,
		salemonth,
		Total_revenue,
		LAG(Total_Revenue) OVER (PARTITION BY PRODUCT ORDER BY Saleyear,Salemonth) AS prev_Sales,
		Total_Revenue -	LAG(Total_Revenue) OVER (PARTITION BY PRODUCT ORDER BY Saleyear,Salemonth) AS Sales_Change
	FROM Monthly_sales
),
Decline AS (
	SELECT 
		Product,
		Saleyear,
		salemonth,
		Total_revenue,
		Prev_sales,
		Sales_Change,
	CASE 
		WHEN Sales_Change < 0
		THEN 1 
		ELSE 0
	END AS Is_declining
	FROM Sales_with_change
),
Decline_Streaks AS (
	SELECT 
		Product,
		Saleyear,
		salemonth,
		Total_revenue,
		Prev_sales,
		Sales_Change,
		Is_declining,
	ROW_NUMBER() OVER (PARTITION BY Product ORDER BY Saleyear,Salemonth) -
	ROW_NUMBER() OVER (PARTITION BY Product,Is_declining ORDER BY Saleyear,Salemonth) AS grp
	FROM Decline
)
SELECT DISTINCT	
	Product
FROM Decline_Streaks
WHERE Is_declining = 1
GROUP BY Product,grp
HAVING COUNT(*) >= 3

---9. Average time between two purchases by a customer.
WITH CustomerPurchaseDiff AS (
    SELECT 
        CustomerID,
        OrderDate,
        LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PrevOrderDate
    FROM Sales.Orders
)
SELECT 
    CustomerID,
    AVG(DATEDIFF(DAY, PrevOrderDate, OrderDate) * 1.0) AS AvgDaysBetweenPurchases
FROM CustomerPurchaseDiff
WHERE PrevOrderDate IS NOT NULL
GROUP BY CustomerID
ORDER BY AvgDaysBetweenPurchases;

---10. Active vs inactive customers per quarter.
WITH Customer_Activity AS (
    SELECT 
        c.CustomerID,
        CONCAT('Q', DATEPART(QUARTER, o.OrderDate), '-', YEAR(o.OrderDate)) AS QuarterYear
    FROM Sales.Customers AS c
    LEFT JOIN Sales.Orders AS o 
        ON c.CustomerID = o.CustomerID
)
, Active_Customer_Count AS (
    SELECT 
        QuarterYear,
        COUNT(DISTINCT CustomerID) AS Active_Customers
    FROM Customer_Activity
    WHERE QuarterYear IS NOT NULL
    GROUP BY QuarterYear
)
SELECT 
    a.QuarterYear,
    a.Active_Customers,
    (SELECT COUNT(*) FROM Sales.Customers) - a.Active_Customers AS Inactive_Customers
FROM Active_Customer_Count AS a
ORDER BY a.QuarterYear;

---11. Customers with no purchases in the last 3 months.
SELECT 
	a.Customerid,
	Customername,
	MAX(b.OrderDate) AS LastOrderDate,
	DATEDIFF(MONTH,MAX(OrderDate),GETDATE()) Monthsince_lastorder
FROM Sales.Customers a
LEFT JOIN Sales.Orders b ON a.CustomerID = b.CustomerID
LEFT JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
GROUP BY a.CustomerID,Customername
HAVING DATEDIFF(MONTH,MAX(OrderDate),GETDATE()) > 3 OR MAX(b.OrderDate) IS NULL 

---12. Repeat purchase rate by StateProvince.
WITH Customer_Order_Count AS (
    SELECT 
        c.CustomerID,
        e.StateProvinceName,
        COUNT(DISTINCT a.OrderID) AS OrderCount
    FROM Sales.OrderLines a
    LEFT JOIN Sales.Orders b ON a.OrderID = b.OrderID
    JOIN Sales.Customers c ON b.CustomerID = c.CustomerID
    JOIN Application.Cities d ON c.DeliveryCityID = d.CityID
    JOIN Application.StateProvinces e ON d.StateProvinceID = e.StateProvinceID
    GROUP BY c.CustomerID,e.StateProvinceName
)
SELECT 
    StateProvinceName,
	COUNT(CASE WHEN OrderCount >= 2 THEN 1 END) AS RepeatCustomers,
    COUNT(CASE WHEN OrderCount >= 2 THEN 1 END) * 100.0 /
        NULLIF(COUNT(CASE WHEN OrderCount >= 1 THEN 1 END), 0) AS Repeat_Purchase_Rate
FROM Customer_Order_Count
GROUP BY StateProvinceName
ORDER BY Repeat_Purchase_Rate DESC;

---13. Percentage of customers accounting for 80% of revenue.

WITH Customer_Revenue AS (
    SELECT 
        a.CustomerID,
        SUM(c.PickedQuantity * c.UnitPrice) AS Total_Revenue
    FROM Sales.Customers AS a
    JOIN Sales.Orders AS b ON a.CustomerID = b.CustomerID
    JOIN Sales.OrderLines AS c ON b.OrderID = c.OrderID
    GROUP BY a.CustomerID
),
Ranked_Customers AS (
    SELECT 
        CustomerID,
        Total_Revenue,
        SUM(Total_Revenue) OVER () AS Total_Revenue_All,
        SUM(Total_Revenue) OVER (ORDER BY Total_Revenue DESC) AS Cumulative_Revenue,
        ROW_NUMBER() OVER (ORDER BY Total_Revenue DESC) AS Rank_Num,
        COUNT(*) OVER () AS Total_Customers
    FROM Customer_Revenue
)
SELECT 
    COUNT(*) * 100.0 / MAX(Total_Customers) AS Customers_For_80pct_Revenue
FROM Ranked_Customers
WHERE Cumulative_Revenue <= 0.8 * Total_Revenue_All;

---14. One-time buyers vs repeat buyers.

WITH Customer_Purchase_Count AS (
    SELECT 
        CustomerID,
        COUNT(DISTINCT OrderID) AS Total_Orders
    FROM Sales.Orders
    GROUP BY CustomerID
)
SELECT 
    CASE 
        WHEN Total_Orders = 1 THEN 'One-time Buyer'
        ELSE 'Repeat Buyer'
    END AS Buyer_Type,
    COUNT(*) AS Customer_Count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS Percentage
FROM Customer_Purchase_Count
GROUP BY 
    CASE 
        WHEN Total_Orders = 1 THEN 'One-time Buyer'
        ELSE 'Repeat Buyer'
    END;

---15. Average selling price vs cost per product.
SELECT 
    b.StockItemName AS ProductName,
    ROUND(AVG(a.UnitPrice), 2) AS Avg_Selling_Price,
    ROUND(AVG(c.LastCostPrice), 2) AS Avg_Cost_Price,
    ROUND(AVG(a.UnitPrice) - AVG(c.LastCostPrice), 2) AS Profit_Per_Unit,
    ROUND(((AVG(a.UnitPrice) - AVG(c.LastCostPrice)) * 100.0 / AVG(a.UnitPrice)), 2) AS Profit_Margin_Percent
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings AS c ON b.StockItemID = c.StockItemID
GROUP BY b.StockItemName
ORDER BY Profit_Margin_Percent DESC;

---16. Products generating lowest revenue or profit.

SELECT 
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
    SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
    SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings AS c ON b.StockItemID = c.StockItemID
GROUP BY b.StockItemName
ORDER BY Total_Profit ASC;  

---17. Profit margin per stock group.

SELECT 
    e.StockGroupName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
    SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
    SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit,
    ROUND(
        (SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) 
         / NULLIF(SUM(a.PickedQuantity * a.UnitPrice), 0)) * 100, 2
    ) AS Profit_Margin_Percent
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings AS c ON b.StockItemID = c.StockItemID
JOIN Warehouse.StockItemStockGroups AS d ON b.StockItemID = d.StockItemID
JOIN Warehouse.StockGroups AS e ON d.StockGroupID = e.StockGroupID
GROUP BY e.StockGroupName
ORDER BY Profit_Margin_Percent DESC;

---18. Products frequently purchased together.
SELECT 
    c.StockItemName AS Product_A,
    d.StockItemName AS Product_B,
    COUNT(*) AS Times_Bought_Together
FROM Sales.OrderLines a
JOIN Sales.OrderLines b ON a.OrderID = b.OrderID 
    AND a.StockItemID < b.StockItemID  
JOIN Warehouse.StockItems c ON a.StockItemID = c.StockItemID
JOIN Warehouse.StockItems d ON b.StockItemID = d.StockItemID
GROUP BY c.StockItemName, d.StockItemName
HAVING COUNT(*) > 5 
ORDER BY Times_Bought_Together DESC;

---19. Slow-moving or underperforming products Based on Quantity Sold.
SELECT 
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity) AS Total_Quantity_Sold
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
GROUP BY b.StockItemName
ORDER BY Total_Quantity_Sold ASC;   

---20. Slow-moving or underperforming products Based on Based on Revenue.
SELECT 
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
GROUP BY b.StockItemName
ORDER BY Total_Revenue ASC;

---21. Average order completion time.
SELECT 
    AVG(DATEDIFF(DAY, OrderDate, PickingCompletedWhen)* 1.0) AS Avg_Order_Completion_Days
FROM Sales.Orders
WHERE PickingCompletedWhen IS NOT NULL;

---22. Ratio of successful to failed transactions.
SELECT 
    SUM(CASE WHEN PickingCompletedWhen IS NOT NULL THEN 1 ELSE 0 END) AS Successful_Transactions,
    SUM(CASE WHEN PickingCompletedWhen IS NULL THEN 1 ELSE 0 END) AS Failed_or_Pending_Transactions,
    CAST(SUM(CASE WHEN PickingCompletedWhen IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) /
    NULLIF(SUM(CASE WHEN PickingCompletedWhen IS NULL THEN 1 ELSE 0 END), 0) AS Success_to_Failure_Ratio
FROM Sales.Orders;

---23. Suppliers with delayed deliveries .
SELECT 
    b.SupplierName,
    COUNT(a.PurchaseOrderID) AS Total_Orders,
    SUM(CASE WHEN c.Finalizationdate > a.ExpectedDeliveryDate THEN 1 ELSE 0 END) AS Delayed_Orders,
    ROUND(
        SUM(CASE WHEN c.FinalizationDate > a.ExpectedDeliveryDate THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(a.PurchaseOrderID), 2
    ) AS Delay_Percentage
FROM Purchasing.PurchaseOrders AS a
JOIN Purchasing.Suppliers AS b ON a.SupplierID = b.SupplierID
LEFT JOIN Purchasing.SupplierTransactions AS c ON a.PurchaseOrderID = c.PurchaseOrderID 
WHERE c.FinalizationDate IS NOT NULL
GROUP BY b.SupplierName
ORDER BY Delay_Percentage DESC;


---24. Inventory planning improvement opportunities based on sales trends.
WITH Product_Sales AS (
    SELECT 
        a.StockItemID,
        SUM(a.PickedQuantity) AS Total_Sold_Last_6_Months
    FROM Sales.OrderLines a
    JOIN Sales.Orders b ON a.OrderID = b.OrderID
    WHERE b.OrderDate >= DATEADD(MONTH, -6, GETDATE())
    GROUP BY a.StockItemID
)
SELECT 
    a.StockItemName,
    b.QuantityOnHand,
    c.Total_Sold_Last_6_Months,
    CASE 
        WHEN c.Total_Sold_Last_6_Months > (b.QuantityOnHand * 2) THEN 'Understocked '
        WHEN c.Total_Sold_Last_6_Months < (b.QuantityOnHand / 2.0) THEN 'Overstocked '
        ELSE 'Balanced Stock'
    END AS Inventory_Status
FROM Warehouse.StockItems a
JOIN Warehouse.StockItemHoldings b ON a.StockItemID = b.StockItemID
LEFT JOIN Product_Sales c ON a.StockItemID = c.StockItemID
ORDER BY Inventory_Status, c.Total_Sold_Last_6_Months DESC;





