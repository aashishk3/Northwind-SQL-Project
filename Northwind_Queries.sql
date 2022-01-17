SELECT * FROM northwind.`Order Details`;
SELECT * FROM Products;
SELECT * FROM Orders;
SELECT * FROM Customers;
SELECT * FROM Categories;
SELECT * FROM Employees;
SELECT * FROM Suppliers;

SET sql_mode = (SELECT REPLACE(@@SQL_MODE, "ONLY_FULL_GROUP_BY", ""));

# Top 10 Customers according to their overall spending from 1996 - 1998
SELECT cust.CompanyName, SUM((od.UnitPrice * od.Quantity)) as Total_Spent
FROM Customers cust
JOIN(
	SELECT CustomerID, OrderID, str_to_date(OrderDate, "%Y-%m-%d") as OrderDate
    FROM Orders
    ) AS ord ON cust.CustomerID = ord.CustomerID
JOIN `Order Details` od ON ord.OrderID = od.OrderID
GROUP BY cust.CompanyName
ORDER BY Total_Spent DESC
LIMIT 10;


# Time series - Top 10 Customers over one year period (July 1996 to July 1997)
SELECT cust.CompanyName, SUM((od.UnitPrice * od.Quantity)) as Total_Spent
FROM Customers cust
JOIN(
	SELECT CustomerID, OrderID, str_to_date(OrderDate, "%Y-%m-%d") as OrderDate
    FROM Orders
    ) AS ord ON cust.CustomerID = ord.CustomerID
JOIN `Order Details` od ON ord.OrderID = od.OrderID
WHERE OrderDate BETWEEN "1996-07-01" AND "1997-07-01"
GROUP BY cust.CompanyName
ORDER BY Total_Spent DESC
LIMIT 10;


# How much of each category is each customer ordering? Also how many total units did a customer order?

SELECT cust.CompanyName, c.Category_Name, SUM(od.Quantity) as Qty_Total
FROM Customers cust
JOIN(
	SELECT CustomerID, OrderID
    FROM Orders
    ) AS ord ON cust.CustomerID = ord.CustomerID
JOIN(
	SELECT ProductID, OrderID, Quantity
    FROM `Order Details`
    ) AS od ON ord.OrderID = od.OrderID
JOIN(
	SELECT ProductID, ProductName as Product_Name, CategoryID
    FROM Products
    ) AS p ON od.ProductID = p.ProductID
JOIN(
	SELECT CategoryID, CategoryName as Category_Name
    FROM Categories
    ) AS c ON p.CategoryID = c.CategoryID
GROUP BY cust.CompanyName, c.Category_Name WITH ROLLUP;

# Employee: What is the average lag time between order placed and order shipped for each employee 
# assumming they are responsible for everything?

SELECT CONCAT(FirstName, ' ', LastName) as EmpName, Title, AVG(LagTime) as avgLagTime
FROM Employees e
LEFT JOIN(
	SELECT EmployeeID, DATEDIFF((STR_TO_DATE(ShippedDate, "%Y-%m-%d")), (STR_TO_DATE(OrderDate, "%Y-%m-%d"))) as LagTime
    FROM Orders
    ) AS o ON e.EmployeeID = o.EmployeeID
GROUP BY EmpName
ORDER BY avgLagTime;

# How many times did each employee ship a product after the customer's required date?

SELECT CONCAT(FirstName, ' ', LastName) as EmpName, Title, COUNT(Early_Late) as lateShipment
FROM Employees e
LEFT JOIN(
	SELECT EmployeeID, DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) as Early_Late
    FROM Orders
    ) AS o ON e.EmployeeID = o.EmployeeID
WHERE Early_Late < 0
GROUP BY EmpName
ORDER BY lateShipment DESC;


# How many shipments can be categorized into these shipment statuses (Early, On Time, Running Late & Late Shipment)

SELECT COUNT(OrderID),
CASE 
	WHEN DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) > 15 THEN 'Early'
    WHEN DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) BETWEEN 6 AND 15 THEN 'On Time'
    WHEN DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) BETWEEN 1 AND 5 THEN 'Running Late'
    ELSE 'Late Shipment' 
END AS Shipment_Status
FROM Orders
GROUP BY Shipment_Status;

# Total sales from July 1996 to July 1997 for all products

SELECT c.CategoryName, p.ProductName, SUM((UnitPrice - Discount) * Quantity) as Revenue_gen
FROM `Order Details` od
INNER JOIN(
	SELECT OrderID, OrderDate
    FROM Orders
    WHERE OrderDate BETWEEN "1997-01-01" AND "1997-12-31"
    ) AS o ON od.OrderID = o.OrderID
INNER JOIN(
	SELECT ProductID, ProductName, CategoryID
    FROM Products
    ) AS p ON od.ProductID = p.ProductID
JOIN(
	SELECT CategoryID, CategoryName
    FROM Categories
    ) AS c ON c.CategoryID = p.CategoryID
GROUP BY c.CategoryName, p.ProductName
ORDER BY c.CategoryName, Revenue_gen DESC;

# Price at which product is sold and listed is not the same for every transaction. 
# What is the average sale price of each product and what is the average discount given for each product?

SELECT ProductName, ROUND(UnitPrice,2) AS `Listed Price`, od.AvgPrice,
CONCAT(ROUND(((UnitPrice - od.AvgPrice)/UnitPrice)*100,2),'%') AS AvgDiscountPerc
FROM Products p
LEFT JOIN(
	SELECT ProductID, ROUND((SUM(UnitPrice * Quantity))/(SUM(Quantity)), 2) AS AvgPrice
    FROM `Order Details`
    GROUP BY ProductID
    ) AS od ON p.ProductID = od.ProductID
ORDER BY AvgDiscountPerc DESC;

# Going off the above query, which employee is responsible for giving away the most DISCOUNT 
# (given that they sold over $5000 worth of stuff)?

SELECT e.EmpName, e.Title, ROUND(SUM(od.UnitPrice*od.Quantity),2) as OrderAmt, ROUND(SUM(p.UnitPrice*od.Quantity),2) as ActualAmt,
ROUND(((ROUND(SUM(p.UnitPrice*od.Quantity),2)- ROUND(SUM(od.UnitPrice*od.Quantity),2)) / (ROUND(SUM(p.UnitPrice*od.Quantity),2)))*100,2) AS TotalAvgDiscount
FROM Orders o
LEFT JOIN(
	SELECT OrderID, UnitPrice, Quantity, ProductID
    FROM `Order Details`
    ) AS od ON o.OrderID = od.OrderID
LEFT JOIN(
	SELECT ProductID, UnitPrice
    FROM Products
    ) AS p ON p.ProductID = od.ProductID
LEFT JOIN(
	SELECT EmployeeID, CONCAT(FirstName, ' ', LastName) AS EmpName, Title
    FROM Employees
    ) AS e ON o.EmployeeID = e.EmployeeID
GROUP BY e.EmpName
HAVING OrderAmt > 100000
ORDER BY TotalAvgDiscount DESC;

# Creating a pivot table that shows employee name and the number of times they shipped an order 
# 'early', 'on time', 'running late' or 'late shipment'

WITH t1 AS
	(SELECT CONCAT(FirstName, ' ', LastName) AS EmpName, OrderID,
	CASE 
		WHEN DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) > 15 THEN 'Early'
		WHEN DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) BETWEEN 6 AND 15 THEN 'On Time'
		WHEN DATEDIFF((STR_TO_DATE(RequiredDate, "%Y-%m-%d")), (STR_TO_DATE(ShippedDate, "%Y-%m-%d"))) BETWEEN 1 AND 5 THEN 'Running Late'
		ELSE 'Late Shipment' 
	END AS Shipment_Status
	FROM Orders o
    JOIN Employees e ON o.EmployeeID = e.EmployeeID),
t2 AS
	(SELECT EmpName,
    COUNT((CASE WHEN Shipment_Status = 'Early' THEN Shipment_Status ELSE NULL END)) AS Early,
	COUNT((CASE WHEN Shipment_Status = 'On Time' THEN Shipment_Status ELSE NULL END)) AS `On Time`,
    COUNT((CASE WHEN Shipment_Status = 'Running Late' THEN Shipment_Status ELSE NULL END)) AS `Running Late`,
    COUNT((CASE WHEN Shipment_Status = 'Late Shipment' THEN Shipment_Status ELSE NULL END)) AS `Late Shipment`
	FROM t1
    GROUP BY EmpName)
SELECT *
FROM t2;


#11 Revenue generated by product per year
WITH t1 AS
	(SELECT o.OrderID, o.EmployeeID, CONCAT(FirstName, ' ', LastName) as EmpName, YEAR(OrderDate) AS `Year`
    FROM Orders o
    JOIN Employees e ON o.EmployeeID = e.EmployeeID),
t2 AS
	(SELECT t1.EmpName, od.OrderID, (od.UnitPrice*od.Quantity) as TotalRev, t1.`Year`, p.ProductID, p.ProductName
    FROM `Order Details` od
    JOIN t1 ON od.OrderID = t1.OrderID
    JOIN Products p ON p.ProductID = od.ProductID
    GROUP BY OrderID),
t3 AS    
	(SELECT t2.ProductName,
	SUM(CASE WHEN Year = '1996' THEN TotalRev ELSE NULL END) as `1996`,
	SUM(CASE WHEN Year = '1997' THEN TotalRev ELSE NULL END) as `1997`,
	SUM(CASE WHEN Year = '1998' THEN TotalRev ELSE NULL END) as `1998`
	FROM t2
	GROUP BY t2.ProductName)
SELECT ProductName, COALESCE(`1996`,0) AS Rev1996 , COALESCE(`1997`,0) AS Rev1997, COALESCE(`1998`,0) AS Rev1998
FROM t3;
    
# A running tally of the revenue generated by each product for each order and the Quantity ordered from July 1996 to May 1998. 
CREATE OR REPLACE VIEW REVENUE_QTY_BY_PRODUCT AS
SELECT p.ProductName, DATE(o.OrderDate) as OrderDate, od.UnitPrice, od.Quantity,
ROUND(SUM(od.UnitPrice*od.Quantity) OVER(PARTITION BY p.ProductName,OrderDate ORDER BY OrderDate),2) AS `Revenue for Order`,
ROUND(SUM(od.UnitPrice*od.Quantity) OVER(PARTITION BY p.ProductName ORDER BY OrderDate),2) AS `Cumalative Revenue`,
SUM(od.Quantity) OVER(PARTITION BY p.ProductName ORDER BY OrderDate) AS QtyOrdered
FROM Products p
JOIN `Order Details` od ON p.ProductID = od.ProductID
JOIN Orders o ON o.OrderID = od.OrderID;

#14 The top 5 products and the countries to which the products are shipped to (in terms of Total Rev Generated)
WITH t1 AS
	(SELECT p.ProductName, c.Country, SUM(od.Quantity) as QtyOrdered, od.UnitPrice,
    SUM(SUM(od.Quantity)*od.UnitPrice) OVER(PARTITION BY p.ProductName) AS TotProdRev
	FROM Customers c
	JOIN Orders o ON c.CustomerID = o.CustomerID
	JOIN `Order Details` od ON od.OrderID = o.OrderID
	JOIN Products p ON p.ProductID = od.ProductID
	GROUP BY p.ProductName, c.Country),
t2 AS    
	(SELECT *,
    DENSE_RANK() OVER(ORDER BY TotProdRev DESC) AS `Rank`
	FROM t1)
SELECT *
FROM t2
WHERE `Rank` <= 5
ORDER BY `Rank`, QtyOrdered DESC;

# Revenue per category calculations (for each order) as well as the total revenue over 3 years (TABLEAU)
CREATE OR REPLACE VIEW Category_Rev AS
SELECT p.ProductName, DATE(o.OrderDate) as OrderDate, od.UnitPrice, od.Quantity, c.CategoryName,
ROUND(SUM(od.UnitPrice*od.Quantity) OVER(PARTITION BY c.CategoryName,OrderDate,ProductName),2) AS `Revenue for Category`,
ROUND(SUM(od.UnitPrice*od.Quantity) OVER(PARTITION BY MONTH(OrderDate)),2) AS `Cumalative Revenue`
FROM Products p
JOIN `Order Details` od ON p.ProductID = od.ProductID
JOIN Orders o ON o.OrderID = od.OrderID
JOIN Categories c ON p.CategoryID = c.CategoryID;

CREATE OR REPLACE VIEW TotalRev AS
SELECT DATE(OrderDate) as OrderDate, ROUND(SUM(od.UnitPrice*od.Quantity),2) as TotRev
FROM Categories c
JOIN Products p ON c.CategoryID = p.CategoryID
JOIN `Order Details` od ON od.ProductID = p.ProductID
JOIN Orders o ON o.OrderID = od.OrderID
GROUP BY o.OrderDate;

# Total Revenue for each month over three years (TABLEAU)
SELECT c.CategoryName, ROUND(SUM(od.UnitPrice*od.Quantity),2) as TotRev
FROM Categories c
JOIN Products p ON c.CategoryID = p.CategoryID
JOIN `Order Details` od ON od.ProductID = p.ProductID
JOIN Orders o ON o.OrderID = od.OrderID
WHERE OrderDate < '1998-03-01' AND OrderDate > '1998-01-31'
GROUP BY c.CategoryName;










