/*
ADVANCED LEVEL — Predictive, Profitability & Strategic Analysis

Goal: Deliver insights, KPIs, forecasting, and strategic recommendations.

Strategic Revenue Growth

1. Moving average of sales over 3 or 6 months.
2. High-priority customer segments for growth.
3. Products to discontinue or promote more.
4. Top 20% of products/customers contributing most to profit.
5. Most profitable products
6. Most profitable customers.
7. Most profitable regions.

Financial & Profitability Analysis
8. Top 10 Most Profitable Products
9. Top 10 Least Profitable Products
10. Top 10 Most Profitable Customers
11. Top 10 Least Profitable Customers

12. Cost-to-revenue ratio per product or region.
13. Cumulative revenue and profit over time.
14. Profit margin trends vs sales volume.

Customer Lifetime & Retention Intelligence
15. Customer lifetime value (LTV).
16. Customer segments with highest churn.

Operational Optimization & KPIs
17. Employees handling highest sales volume.
18. Key performance indicators (monthly): total revenue, AOV, retention.
19. Efficiency ratio (orders processed vs failed).

Cross-Domain Analytical Questions
20. Compare this year’s revenue to the same period last year (YoY growth).
21. Identify products with negative or low margins.
22. Analyze sales per weekday to optimize staffing or marketing.
23. Contribution margin per product (`Revenue - Variable Cost`).
24. Rank customers by profit contribution using `RANK()` or `DENSE_RANK()`.
25. Build KPIs: Total Revenue, Profit Margin, Retention Rate, AOV, Growth Rate.

Focus: Window functions, subqueries, KPI modeling, forecasting, multi-table analysis.
*/


---1. Moving average of sales over 3 or 6 months
WITH Monthly_Sales AS (
    SELECT 
        YEAR(b.OrderDate) AS Year,
        MONTH(b.OrderDate) AS Month,
        DATENAME(MONTH, b.OrderDate) AS MonthName,
        SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue
    FROM Sales.OrderLines a
    JOIN Sales.Orders b ON a.OrderID = b.OrderID
    GROUP BY YEAR(b.OrderDate), MONTH(b.OrderDate), DATENAME(MONTH, b.OrderDate)
)
SELECT 
    Year,
    Month,
    MonthName,
    Total_Revenue,
    ROUND(AVG(Total_Revenue) OVER (ORDER BY Year, Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW ), 2 ) AS Moving_Avg_3_Months,
    ROUND(AVG(Total_Revenue) OVER (ORDER BY Year, Month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW), 2) AS Moving_Avg_6_Months
FROM Monthly_Sales
ORDER BY Year, Month;

---2. High-priority customer segments for growth.
WITH Customer_Segment_Summary AS (
    SELECT 
        b.CustomerCategoryName AS Segment,
        COUNT(DISTINCT a.CustomerID) AS Total_Customers,
        SUM(d.PickedQuantity * d.UnitPrice) AS Total_Revenue,
        COUNT(DISTINCT c.OrderID) AS Total_Orders,
        AVG(DATEDIFF(DAY, MIN(c.OrderDate), MAX(c.OrderDate))) AS Avg_Order_Span
    FROM Sales.Customers a
    JOIN Sales.CustomerCategories b ON a.CustomerCategoryID = b.CustomerCategoryID
    JOIN Sales.Orders c ON a.CustomerID = c.CustomerID
    JOIN Sales.OrderLines d ON c.OrderID = d.OrderID
    GROUP BY b.CustomerCategoryName
),
Segment_Ranking AS (
    SELECT 
        Segment,
        Total_Customers,
        Total_Orders,
        Total_Revenue,
        ROUND(Total_Revenue / NULLIF(Total_Customers, 0), 2) AS Revenue_Per_Customer,
        ROUND(Total_Orders * 1.0 / NULLIF(Total_Customers, 0), 2) AS Orders_Per_Customer,
        RANK() OVER (ORDER BY Total_Revenue DESC) AS Revenue_Rank,
        RANK() OVER (ORDER BY Orders_Per_Customer DESC) AS Engagement_Rank
    FROM Customer_Segment_Summary
)
SELECT 
    Segment,
    Total_Customers,
    Total_Revenue,
    Revenue_Per_Customer,
    Orders_Per_Customer,
    (Revenue_Rank + Engagement_Rank) AS Priority_Score
FROM Segment_Ranking
ORDER BY Priority_Score ASC;

---3. Products to discontinue or promote more.
WITH Product_Performance AS (
    SELECT 
        a.StockItemID,
        b.StockItemName,
        SUM(a.PickedQuantity) AS Total_Quantity_Sold,
        SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
        SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit,
        MAX(d.OrderDate) AS Last_Sold_Date
    FROM Sales.OrderLines a
    JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
    JOIN Warehouse.StockItemHoldings c ON b.StockItemID = c.StockItemID
    JOIN Sales.Orders d ON a.OrderID = d.OrderID
    GROUP BY a.StockItemID, b.StockItemName
),
Product_Assessment AS (
    SELECT 
        StockItemName,
        Total_Quantity_Sold,
        Total_Revenue,
        Total_Profit,
        Last_Sold_Date,
        CASE 
            WHEN Total_Quantity_Sold < 50 AND Total_Profit < 1000 
                 AND Last_Sold_Date < DATEADD(MONTH, -6, GETDATE()) THEN 'Discontinue'
            WHEN Total_Profit > 5000 AND Total_Quantity_Sold > 200 THEN 'Promote More'
            ELSE 'Monitor'
        END AS Recommendation
    FROM Product_Performance
)
SELECT 
    StockItemName,
    Total_Quantity_Sold,
    Total_Revenue,
    Total_Profit,
    Last_Sold_Date,
    Recommendation
FROM Product_Assessment
ORDER BY 
    CASE Recommendation 
        WHEN 'Promote More' THEN 1
        WHEN 'Monitor' THEN 2
        WHEN 'Discontinue' THEN 3
    END,
    Total_Profit DESC;

---4. Top 20% of products contributing most to profit
WITH Product_Profit AS (
    SELECT 
        b.StockItemName,
        SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit
    FROM Sales.OrderLines a
    JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
    JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
    GROUP BY b.StockItemName
),
Ranked_Products AS (
    SELECT 
        StockItemName,
        Total_Profit,
        SUM(Total_Profit) OVER () AS Total_Profit_All,
        SUM(Total_Profit) OVER (ORDER BY Total_Profit DESC) AS Cumulative_Profit
    FROM Product_Profit
)
SELECT 
    StockItemName,
    Total_Profit,
    ROUND(Cumulative_Profit * 100.0 / Total_Profit_All, 2) AS Cumulative_Profit_Percent
FROM Ranked_Products
WHERE Cumulative_Profit <= 0.8 * Total_Profit_All  
ORDER BY Total_Profit DESC;

--- 5. Most profitable products
SELECT 
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
    SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
    SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit,
    ROUND((SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) * 100.0) /
        NULLIF(SUM(a.PickedQuantity * a.UnitPrice), 0), 2 ) AS Profit_Margin_Percent
FROM Sales.OrderLines a
JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
GROUP BY b.StockItemName
ORDER BY Total_Profit DESC;

---6. Most profitable customers
SELECT 
    a.CustomerID,
    a.CustomerName,
    SUM(c.PickedQuantity * c.UnitPrice) AS Total_Revenue,
    SUM(c.PickedQuantity * d.LastCostPrice) AS Total_Cost,
    SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) AS Total_Profit,
    ROUND((SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) * 100.0) /
      NULLIF(SUM(c.PickedQuantity * c.UnitPrice), 0), 2) AS Profit_Margin_Percent
FROM Sales.Customers a
JOIN Sales.Orders b ON a.CustomerID = b.CustomerID
JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
JOIN Warehouse.StockItemHoldings d ON c.StockItemID = d.StockItemID
GROUP BY a.CustomerID, a.CustomerName
ORDER BY Total_Profit DESC;

---7. Most profitable regions
SELECT 
    e.StateProvinceName AS Region,
    SUM(b.PickedQuantity * b.UnitPrice) AS Total_Revenue,
    SUM(b.PickedQuantity * f.LastCostPrice) AS Total_Cost,
    SUM(b.PickedQuantity * (b.UnitPrice - f.LastCostPrice)) AS Total_Profit,
    ROUND((SUM(b.PickedQuantity * (b.UnitPrice - f.LastCostPrice)) * 100.0) /
        NULLIF(SUM(b.PickedQuantity * b.UnitPrice), 0), 2) AS Profit_Margin_Percent
FROM Sales.Orders a
JOIN Sales.OrderLines b ON a.OrderID = b.OrderID
JOIN Sales.Customers c ON a.CustomerID = c.CustomerID
JOIN Application.Cities d ON c.DeliveryCityID = d.CityID
JOIN Application.StateProvinces e ON d.StateProvinceID = e.StateProvinceID
JOIN Warehouse.StockItemHoldings f ON b.StockItemID = f.StockItemID
GROUP BY e.StateProvinceName
ORDER BY Total_Profit DESC;

---8. Top 10 Most Profitable Products
WITH ProductProfit AS (
    SELECT 
        b.StockItemName AS ProductName,
        SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
        SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
        SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit,
        ROUND((SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) * 100.0) /
            NULLIF(SUM(a.PickedQuantity * a.UnitPrice), 0), 2) AS Profit_Margin_Percent
    FROM Sales.OrderLines a
    JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
    JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
    GROUP BY b.StockItemName
)
SELECT TOP 10 
    ProductName,
    Total_Revenue,
    Total_Cost,
    Total_Profit,
    Profit_Margin_Percent
FROM ProductProfit
ORDER BY Total_Profit DESC;

---9. Top 10 Least Profitable Products
WITH ProductProfit AS (
    SELECT 
        b.StockItemName AS ProductName,
        SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
        SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
        SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit,
        ROUND((SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) * 100.0) /
            NULLIF(SUM(a.PickedQuantity * a.UnitPrice), 0), 2) AS Profit_Margin_Percent
    FROM Sales.OrderLines a
    JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
    JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
    GROUP BY b.StockItemName
)

SELECT TOP 10 
    ProductName,
    Total_Revenue,
    Total_Cost,
    Total_Profit,
    Profit_Margin_Percent
FROM ProductProfit
ORDER BY Total_Profit ASC;

-- 10. Top 10 Most Profitable Customers
WITH CustomerProfit AS (
    SELECT 
        a.CustomerName,
        SUM(c.PickedQuantity * c.UnitPrice) AS Total_Revenue,
        SUM(c.PickedQuantity * d.LastCostPrice) AS Total_Cost,
        SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) AS Total_Profit,
        ROUND((SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) * 100.0) /
            NULLIF(SUM(c.PickedQuantity * c.UnitPrice), 0), 2) AS Profit_Margin_Percent
    FROM Sales.Customers a
    JOIN Sales.Orders b ON a.CustomerID = b.CustomerID
    JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
    JOIN Warehouse.StockItemHoldings d ON c.StockItemID = d.StockItemID
    GROUP BY a.CustomerName
)
SELECT TOP 10 
    CustomerName,
    Total_Revenue,
    Total_Cost,
    Total_Profit,
    Profit_Margin_Percent
FROM CustomerProfit
ORDER BY Total_Profit DESC;

---11. Top 10 Least Profitable Customers
WITH CustomerProfit AS (
    SELECT 
        a.CustomerName,
        SUM(c.PickedQuantity * c.UnitPrice) AS Total_Revenue,
        SUM(c.PickedQuantity * d.LastCostPrice) AS Total_Cost,
        SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) AS Total_Profit,
        ROUND((SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) * 100.0) /
            NULLIF(SUM(c.PickedQuantity * c.UnitPrice), 0), 2) AS Profit_Margin_Percent
    FROM Sales.Customers a
    JOIN Sales.Orders b ON a.CustomerID = b.CustomerID
    JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
    JOIN Warehouse.StockItemHoldings d ON c.StockItemID = d.StockItemID
    GROUP BY a.CustomerName
)
SELECT TOP 10 
    CustomerName,
    Total_Revenue,
    Total_Cost,
    Total_Profit,
    Profit_Margin_Percent
FROM CustomerProfit
ORDER BY Total_Profit ASC;

---12. Cost-to-Revenue Ratio per Product
SELECT 
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
    SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
    ROUND((SUM(a.PickedQuantity * c.LastCostPrice) * 100.0) /
        NULLIF(SUM(a.PickedQuantity * a.UnitPrice), 0), 2) AS Cost_to_Revenue_Ratio_Percent
FROM Sales.OrderLines a
JOIN Warehouse.StockItems b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
GROUP BY b.StockItemName
ORDER BY Cost_to_Revenue_Ratio_Percent ASC;

---13. Cumulative Revenue and Profit Over Time (by Month)
WITH MonthlyProfit AS (
    SELECT 
        YEAR(b.OrderDate) AS SaleYear,
        MONTH(b.OrderDate) AS SaleMonth,
        DATENAME(MONTH, b.OrderDate) AS MonthName,
        SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
        SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
        SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit
    FROM Sales.OrderLines a
    JOIN Sales.Orders b ON a.OrderID = b.OrderID
    JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
    GROUP BY YEAR(b.OrderDate), MONTH(b.OrderDate), DATENAME(MONTH, b.OrderDate)
)
SELECT 
    SaleYear,
    SaleMonth,
    MonthName,
    Total_Revenue,
    Total_Profit,
    SUM(Total_Revenue) OVER (ORDER BY SaleYear, SaleMonth ROWS UNBOUNDED PRECEDING) AS Cumulative_Revenue,
    SUM(Total_Profit) OVER (ORDER BY SaleYear, SaleMonth ROWS UNBOUNDED PRECEDING) AS Cumulative_Profit
FROM MonthlyProfit
ORDER BY SaleYear, SaleMonth;

---14. Profit Margin Trends vs Sales Volume
WITH MonthlySales AS (
    SELECT 
        YEAR(b.OrderDate) AS SaleYear,
        MONTH(b.OrderDate) AS SaleMonth,
        DATENAME(MONTH, b.OrderDate) AS MonthName,
        SUM(a.PickedQuantity) AS Total_Units_Sold,
        SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
        SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
        SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit
    FROM Sales.OrderLines a
    JOIN Sales.Orders b ON a.OrderID = b.OrderID
    JOIN Warehouse.StockItemHoldings c ON a.StockItemID = c.StockItemID
    GROUP BY YEAR(b.OrderDate), MONTH(b.OrderDate), DATENAME(MONTH, b.OrderDate)
)
SELECT 
    SaleYear,
    SaleMonth,
    MonthName,
    Total_Units_Sold,
    Total_Revenue,
    Total_Profit,
    ROUND((Total_Profit * 100.0) / NULLIF(Total_Revenue, 0), 2) AS Profit_Margin_Percent
FROM MonthlySales
ORDER BY SaleYear, SaleMonth;


---15. Customer Lifetime Value (LTV)
WITH Customer_LTV AS (
    SELECT 
        a.CustomerID,
        a.CustomerName,
        SUM(c.PickedQuantity * c.UnitPrice) AS Total_Revenue,
        SUM(c.PickedQuantity * d.LastCostPrice) AS Total_Cost,
        SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) AS Total_Profit,
        COUNT(DISTINCT b.OrderID) AS Total_Orders,
        MIN(b.OrderDate) AS First_Purchase_Date,
        MAX(b.OrderDate) AS Last_Purchase_Date,
        DATEDIFF(DAY, MIN(b.OrderDate), MAX(b.OrderDate)) AS Customer_Lifespan_Days
    FROM Sales.Customers a
    JOIN Sales.Orders b ON a.CustomerID = b.CustomerID
    JOIN Sales.OrderLines c ON b.OrderID = c.OrderID
    JOIN Warehouse.StockItemHoldings d ON c.StockItemID = d.StockItemID
    GROUP BY a.CustomerID, a.CustomerName
)
SELECT 
    CustomerID,
    CustomerName,
    Total_Orders,
    Total_Revenue,
    Total_Cost,
    Total_Profit,
    ROUND(Total_Revenue / NULLIF(Total_Orders, 0), 2) AS Avg_Order_Value,
    ROUND(Total_Profit / NULLIF(Total_Orders, 0), 2) AS Avg_Profit_per_Order,
    Customer_Lifespan_Days,
    ROUND(Total_Profit, 2) AS Lifetime_Profit_Value,
    ROUND(Total_Revenue, 2) AS Lifetime_Revenue_Value
FROM Customer_LTV
ORDER BY Total_Profit DESC;

---16. Customer segments with highest churn
WITH Last_Purchase AS (
    SELECT 
        a.CustomerID,
        c.CustomerCategoryName,
        MAX(b.OrderDate) AS LastOrderDate
    FROM Sales.Customers AS a
    LEFT JOIN Sales.Orders AS b ON a.CustomerID = b.CustomerID
    LEFT JOIN Sales.CustomerCategories AS c ON a.CustomerCategoryID = c.CustomerCategoryID
    GROUP BY a.CustomerID, c.CustomerCategoryName
),
Churn_Flag AS (
    SELECT 
        CustomerCategoryName,
        CASE 
            WHEN LastOrderDate IS NULL THEN 1  -- Never purchased
            WHEN DATEDIFF(MONTH, LastOrderDate, GETDATE()) > 3 THEN 1  -- Inactive > 3 months
            ELSE 0
        END AS Is_Churned
    FROM Last_Purchase
)
SELECT 
    CustomerCategoryName,
    COUNT(*) AS Total_Customers,
    SUM(Is_Churned) AS Churned_Customers,
    ROUND(SUM(Is_Churned) * 100.0 / COUNT(*), 2) AS Churn_Rate_Percent
FROM Churn_Flag
GROUP BY CustomerCategoryName
ORDER BY Churn_Rate_Percent DESC;

---17. Employees handling highest sales volume
SELECT 
    c.FullName AS EmployeeName,
    SUM(b.PickedQuantity * b.UnitPrice) AS Total_Sales
FROM Sales.Orders AS a
JOIN Sales.OrderLines AS b ON a.OrderID = b.OrderID
JOIN Application.People AS c ON a.SalespersonPersonID = c.PersonID
GROUP BY c.FullName
ORDER BY Total_Sales DESC;

---18. Key Performance Indicators (Monthly)
WITH Monthly_Metrics AS (
    SELECT 
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        DATENAME(MONTH, OrderDate) AS MonthName,
        SUM(b.PickedQuantity * b.UnitPrice) AS Total_Revenue,
        COUNT(DISTINCT a.OrderID) AS Total_Orders,
        COUNT(DISTINCT a.CustomerID) AS Active_Customers
    FROM Sales.Orders AS a
    JOIN Sales.OrderLines AS b ON a.OrderID = b.OrderID
    GROUP BY YEAR(OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
),
Retention AS (
    SELECT 
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        COUNT(DISTINCT CustomerID) AS Returning_Customers
    FROM Sales.Orders
    WHERE CustomerID IN (
        SELECT CustomerID
        FROM Sales.Orders
        WHERE OrderDate < DATEADD(MONTH, -1, GETDATE())
    )
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT 
    m.Year,
    m.MonthName,
    m.Total_Revenue,
    ROUND(m.Total_Revenue / NULLIF(m.Total_Orders, 0), 2) AS Avg_Order_Value,
    m.Active_Customers,
    ISNULL(r.Returning_Customers, 0) AS Returning_Customers,
    ROUND(
        ISNULL(r.Returning_Customers, 0) * 100.0 / NULLIF(m.Active_Customers, 0), 
        2
    ) AS Retention_Rate_Percent
FROM Monthly_Metrics AS m
LEFT JOIN Retention AS r 
    ON m.Year = r.Year AND m.Month = r.Month
ORDER BY m.Year, m.Month;

---19. Efficiency ratio: orders processed vs failed
SELECT 
    COUNT(*) AS Total_Orders,
    SUM(CASE WHEN PickingCompletedWhen IS NOT NULL THEN 1 ELSE 0 END) AS Processed_Orders,
    SUM(CASE WHEN PickingCompletedWhen IS NULL THEN 1 ELSE 0 END) AS Failed_Orders,
    ROUND(SUM(CASE WHEN PickingCompletedWhen IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(*), 2) AS Efficiency_Ratio_Percent
FROM Sales.Orders;

---20. Year-over-Year Revenue Growth
WITH Yearly_Revenue AS (
    SELECT 
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        DATENAME(MONTH, OrderDate) AS MonthName,
        SUM(PickedQuantity * UnitPrice) AS Total_Revenue
    FROM Sales.OrderLines AS a
    JOIN Sales.Orders AS b ON a.OrderID = b.OrderID
    GROUP BY YEAR(OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate)
)
SELECT
    Year,
    MonthName,
    Total_Revenue,
    LAG(Total_Revenue) OVER (PARTITION BY Month ORDER BY Year) AS Revenue_Last_Year,
    ROUND((Total_Revenue - LAG(Total_Revenue) OVER (PARTITION BY Month ORDER BY Year)) * 100.0 /
        NULLIF(LAG(Total_Revenue) OVER (PARTITION BY Month ORDER BY Year), 0),2) AS YoY_Growth_Percent
FROM Yearly_Revenue
ORDER BY Year, Month;

-- 21. Products with negative or low margins
SELECT 
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
    SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Cost,
    SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Total_Profit,
    ROUND((SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) * 100.0) /
        NULLIF(SUM(ol.PickedQuantity * ol.UnitPrice), 0), 2) AS Profit_Margin_Percent
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings AS c ON b.StockItemID = c.StockItemID
GROUP BY b.StockItemName
HAVING 
    SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) <= 0 OR 
    (SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) * 100.0 / NULLIF(SUM(a.PickedQuantity * a.UnitPrice),0)) < 5
ORDER BY Profit_Margin_Percent ASC;

---22. Analyze sales per weekday
SELECT 
    DATENAME(WEEKDAY, a.OrderDate) AS Weekday,
    DATEPART(WEEKDAY, a.OrderDate) AS Weekday_Num,
    COUNT(DISTINCT a.OrderID) AS Total_Orders,
    SUM(b.PickedQuantity * b.UnitPrice) AS Total_Revenue,
    ROUND(SUM(b.PickedQuantity * b.UnitPrice) * 1.0 / COUNT(DISTINCT a.OrderID), 2) AS Avg_Order_Value
FROM Sales.Orders AS a
JOIN Sales.OrderLines AS b ON a.OrderID = b.OrderID
GROUP BY DATENAME(WEEKDAY, a.OrderDate), DATEPART(WEEKDAY, a.OrderDate)
ORDER BY Weekday_Num;

-- 23. Contribution margin per product
SELECT
    b.StockItemName AS ProductName,
    SUM(a.PickedQuantity * a.UnitPrice) AS Total_Revenue,
    SUM(a.PickedQuantity * c.LastCostPrice) AS Total_Variable_Cost,
    SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) AS Contribution_Margin,
    ROUND((SUM(a.PickedQuantity * (a.UnitPrice - c.LastCostPrice)) * 100.0) /
        NULLIF(SUM(a.PickedQuantity * a.UnitPrice), 0), 2) AS Contribution_Margin_Percent
FROM Sales.OrderLines AS a
JOIN Warehouse.StockItems AS b ON a.StockItemID = b.StockItemID
JOIN Warehouse.StockItemHoldings AS c ON b.StockItemID = c.StockItemID
GROUP BY b.StockItemName
ORDER BY Contribution_Margin DESC;

---24. Rank customers by profit contribution
WITH Customer_Profit AS (
    SELECT
        a.CustomerID,
        a.CustomerName,
        SUM(c.PickedQuantity * c.UnitPrice) AS Total_Revenue,
        SUM(c.PickedQuantity * d.LastCostPrice) AS Total_Cost,
        SUM(c.PickedQuantity * (c.UnitPrice - d.LastCostPrice)) AS Total_Profit
    FROM Sales.Customers AS a
    JOIN Sales.Orders AS b ON a.CustomerID = b.CustomerID
    JOIN Sales.OrderLines AS c ON b.OrderID = c.OrderID
    JOIN Warehouse.StockItemHoldings AS d ON d.StockItemID = c.StockItemID
    GROUP BY a.CustomerID, a.CustomerName
)
SELECT
    CustomerID,
    CustomerName,
    Total_Revenue,
    Total_Cost,
    Total_Profit,
    RANK() OVER (ORDER BY Total_Profit DESC) AS Profit_Rank,
    DENSE_RANK() OVER (ORDER BY Total_Profit DESC) AS Profit_DenseRank
FROM Customer_Profit
ORDER BY Total_Profit DESC;


-- 25. Key Performance Indicators (Monthly)
WITH Monthly_Orders AS (
    SELECT 
        YEAR(a.OrderDate) AS Year,
        MONTH(a.OrderDate) AS Month,
        DATENAME(MONTH, a.OrderDate) AS MonthName,
        COUNT(DISTINCT a.OrderID) AS Total_Orders,
        COUNT(DISTINCT a.CustomerID) AS Active_Customers,
        SUM(b.PickedQuantity * b.UnitPrice) AS Total_Revenue,
        SUM(b.PickedQuantity * d.LastCostPrice) AS Total_Cost
    FROM Sales.Orders a
    JOIN Sales.OrderLines b ON a.OrderID = b.OrderID
    JOIN Warehouse.StockItemHoldings d ON b.StockItemID = d.StockItemID
    GROUP BY YEAR(a.OrderDate), MONTH(a.OrderDate), DATENAME(MONTH, a.OrderDate)
),
Retention AS (
    SELECT 
        YEAR(o.OrderDate) AS Year,
        MONTH(o.OrderDate) AS Month,
        COUNT(DISTINCT CustomerID) AS Returning_Customers
    FROM Sales.Orders o
    WHERE CustomerID IN (
        SELECT CustomerID
        FROM Sales.Orders
        WHERE OrderDate < DATEADD(MONTH, -1, GETDATE())
    )
    GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate)
)
SELECT
    m.Year,
    m.MonthName,
    m.Total_Revenue,
    ROUND((m.Total_Revenue - m.Total_Cost) * 100.0 / NULLIF(m.Total_Revenue,0),2) AS Profit_Margin_Percent,
    ROUND(m.Total_Revenue / NULLIF(m.Total_Orders,0),2) AS Avg_Order_Value,
    m.Active_Customers,
    ISNULL(r.Returning_Customers,0) AS Returning_Customers,
    ROUND(ISNULL(r.Returning_Customers,0) * 100.0 / NULLIF(m.Active_Customers,0),2) AS Retention_Rate_Percent,
    LAG(m.Total_Revenue) OVER (ORDER BY m.Year, m.Month) AS Prev_Month_Revenue,
    ROUND((m.Total_Revenue - LAG(m.Total_Revenue) OVER (ORDER BY m.Year, m.Month)) * 100.0 / 
        NULLIF(LAG(m.Total_Revenue) OVER (ORDER BY m.Year, m.Month),0),2) AS MoM_Growth_Rate_Percent
FROM Monthly_Orders m
LEFT JOIN Retention r ON m.Year = r.Year AND m.Month = r.Month
ORDER BY m.Year, m.Month;
