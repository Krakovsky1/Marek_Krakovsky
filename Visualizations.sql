-- Graf 1. Výkonnosť zamestnancov
SELECT 
    e.EmployeeName AS "Zamestnanec",
    SUM(f.TotalRevenue) AS "Celkové tržby"
FROM FactOrders f
JOIN DimEmployees e ON f.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeName
ORDER BY "Celkové tržby" DESC;

-- Graf 2. Predaj podľa mesiacov
SELECT 
    t.MonthName AS "Mesiac",
    SUM(f.TotalRevenue) AS "Celkové tržby"
FROM FactOrders f
JOIN DimTime t ON f.OrderDate = t.DateKey
GROUP BY t.Month, t.MonthName
ORDER BY t.Month;

-- Graf 3. Produkty s najväčším predajom
SELECT 
    p.ProductName AS "Produkt",
    SUM(f.TotalRevenue) AS "Celkové tržby"
FROM FactOrders f
JOIN DimProducts p ON f.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY "Celkové tržby" DESC;

-- Graf 4. Top 10 produktov podľa počtu objednávok
SELECT 
    p.ProductName AS "Produkt",
    COUNT(f.OrderID) AS "Počet objednávok"
FROM FactOrders f
JOIN DimProducts p ON f.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY "Počet objednávok" DESC
LIMIT 10;

-- Graf 5. Predaje podľa dopravcov
SELECT 
    s.ShipperName AS "Dopravca",
    p.ProductName AS "Produkt",
    COUNT(f.OrderID) AS "Počet objednávok",
    SUM(f.TotalRevenue) AS "Celkové tržby"
FROM FactOrders f
JOIN DimProducts p ON f.ProductID = p.ProductID
JOIN DimShippers s ON f.ShipperID = s.ShipperID
GROUP BY s.ShipperName, p.ProductName
ORDER BY "Celkové tržby" DESC
LIMIT 10;

-- Graf 6. Predaje podľa kategórií
SELECT 
    c.CategoryName AS "Kategória",
    SUM(f.TotalRevenue) AS "Celkové tržby"
FROM FactOrders f
JOIN DimProducts p ON f.ProductID = p.ProductID
JOIN DimCategories c ON p.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY "Celkové tržby" DESC;
