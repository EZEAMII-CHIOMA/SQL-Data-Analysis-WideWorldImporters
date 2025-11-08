SQL Analysis with WideWorldImporters

Welcome to the SQL Analysis with WideWorldImporters repository!

This repository is designed to guide anyone starting with SQL, from beginner to advanced levels, using the WideWorldImporters sample database. The goal is practical learning through writing queries to answer real-world business questions. No visualizations are included  the focus is purely on querying, aggregating, and analyzing data.

![image](https://plus.unsplash.com/premium_photo-1661963312443-e6f80b64ace6?fm=jpg&ixid=M3wxMjA3fDB8MHxzZWFyY2h8OXx8bG9naXN0aWNzfGVufDB8fDB8fHww&ixlib=rb-4.1.0&q=60&w=3000)



Purpose

 Learn how to explore, analyze, and summarize data using SQL.
 Understand data relationships in a realistic business dataset.
 Progress from basic descriptive analysis to advanced predictive and strategic analysis.
 Gain confidence in writing queries involving aggregations, joins, window functions, CTEs, and conditional logic.


Dataset

The repository uses the WideWorldImporters database, which includes tables for:

* Customers & Orders
* Products & Categories
* Sales & Returns
* Stock & Suppliers
* Employee & Territory data ETC

> This dataset simulates a real-world business, making it ideal for practicing SQL queries.

Learning Path

The queries are organized by difficulty:

1. Beginner — Data Exploration & Descriptive Analysis

Focus: Summarize, filter, and retrieve data to understand business metrics.
Examples:

 Total revenue generated monthly, quarterly, and yearly
 Top products by sales revenue
 Total quantity sold per product
 Customers with the highest number of orders
 Stock movement trends

> Techniques: SUM(), COUNT(), AVG(), GROUP BY, WHERE, simple joins


2. Intermediate — Diagnostic & Comparative Analysis

Focus: Identify patterns, relationships, and reasons behind performance.
Examples:

 Month-over-month and year-over-year revenue growth
 Fastest-growing product categories or regions
 Repeat purchase rate by region
 Slow-moving or underperforming products
 Average time between purchases

> Techniques: Multiple joins, CTEs, CASE WHEN, date calculations, correlated subqueries


3. Advanced — Predictive, Profitability & Strategic Analysis

Focus: Deliver insights, KPIs and strategic recommendations.
Examples:

 Customer Lifetime Value (LTV)
 Top 20% of products/customers contributing most to profit
 Moving averages of sales
 Profit margin trends vs sales volume
 Contribution margin per product

> Techniques: Window functions, advanced aggregations, grouping sets, ranking functions, performance analysis

How to Use

1. Set up the database:
    Download and attach the WideWorldImporters database in your SQL Server instance.  
    You can find it on Microsoft's official site or in SQL Server sample databases.

2. Connect to the database: 
    Open your SQL client (SQL Server Management Studio, Azure Data Studio, etc.).  
    Connect to the server where you attached the database.  
    Select the WideWorldImporters database to start running the queries.

3. Explore queries folder:

beginner — Basic queries
intermediate — Diagnostic & comparative queries
advanced — Strategic & predictive queries

4. Execute queries, understand the results, and experiment by modifying conditions or joining additional tables.

Key Learning Outcomes

By working through these queries, you will:

 Understand key SQL functions and techniques
 Learn to analyze business performance and profitability
 Develop skills to answer strategic business questions
 Gain confidence for real-world SQL scenarios


 Contribution

Contributions are welcome! You can:

 Add new queries
 Improve existing queries
 Suggest additional business questions

Start your SQL learning journey today — from basic exploration to advanced strategic analysis, all using real-world data!

