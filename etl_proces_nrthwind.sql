-- Vytvorenie databázy
CREATE DATABASE NORTHWIND_DB;

-- Vytvorenie schémy pre staging tabuľky
CREATE SCHEMA NORTHWIND_DB.PUBLIC;
USE DATABASE NORTHWIND_DB;
USE SCHEMA PUBLIC;

-- Vytvorenie tabuľky categories (staging)
CREATE OR REPLACE TABLE categories_staging (
    CategoryID INTEGER,
    CategoryName VARCHAR(25),
    Description VARCHAR(255)
);

-- Vytvorenie tabuľky customers (staging)
CREATE OR REPLACE TABLE customers_staging (
    CustomerID INTEGER,
    CustomerName VARCHAR(50),
    ContactName VARCHAR(50),
    City VARCHAR(20),
    Country VARCHAR(15)
);

-- Vytvorenie tabuľky employees (staging)
CREATE OR REPLACE TABLE employees_staging (
    EmployeeID INTEGER,
    LastName VARCHAR(50),
    FirstName VARCHAR(50),
    BirthDate DATE,
    Notes VARCHAR(1024)
);

-- Vytvorenie tabuľky shippers (staging)
CREATE OR REPLACE TABLE shippers_staging (
    ShipperID INTEGER,
    ShipperName VARCHAR(25)
);

-- Vytvorenie tabuľky products (staging)
CREATE OR REPLACE TABLE products_staging (
    ProductID INTEGER,
    ProductName VARCHAR(50),
    SupplierID INTEGER,
    CategoryID INTEGER,
    Unit VARCHAR(25),
    Price DECIMAL(10, 2)
);

-- Vytvorenie tabuľky suppliers (staging)
CREATE OR REPLACE TABLE suppliers_staging (
    SupplierID INTEGER,
    SupplierName VARCHAR(50),
    ContactName VARCHAR(50),
    Address VARCHAR(50),
    City VARCHAR(20),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(15)
);

-- Vytvorenie tabuľky orders (staging)
CREATE OR REPLACE TABLE orders_staging (
    OrderID INTEGER,
    CustomerID INTEGER,
    EmployeeID INTEGER,
    OrderDate DATE,
    ShipperID INTEGER
);

-- Vytvorenie tabuľky orderdetails (staging)
CREATE OR REPLACE TABLE orderdetails_staging (
    OrderDetailID INTEGER,
    OrderID INTEGER,
    ProductID INTEGER,
    Quantity INTEGER
);

-- Vytvorenie stage pre .csv súbory
CREATE OR REPLACE STAGE northwind_stage;

-- Načítanie dát do staging tabuliek
COPY INTO categories_staging
FROM @northwind_stage/categories.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO customers_staging
FROM @northwind_stage/customers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO employees_staging
FROM @northwind_stage/employees.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO shippers_staging
FROM @northwind_stage/shippers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO products_staging
FROM @northwind_stage/products.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO suppliers_staging
FROM @northwind_stage/suppliers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO orders_staging
FROM @northwind_stage/orders.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

COPY INTO orderdetails_staging
FROM @northwind_stage/orderdetails.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';

-- ELT - (T)ransform
-- DimCustomers
CREATE TABLE DimCustomers AS
SELECT DISTINCT
    CustomerID,
    CustomerName,
    ContactName,
    City,
    Country
FROM customers_staging;

-- DimEmployees
CREATE TABLE DimEmployees AS
SELECT DISTINCT
    EmployeeID,
    CONCAT(FirstName, ' ', LastName) AS EmployeeName,
    BirthDate,
    Notes
FROM employees_staging;

-- DimShippers
CREATE TABLE DimShippers AS
SELECT DISTINCT
    ShipperID,
    ShipperName
FROM shippers_staging;

-- DimProducts
CREATE TABLE DimProducts AS
SELECT DISTINCT
    ProductID,
    ProductName,
    CategoryID,
    SupplierID,
    Price
FROM products_staging;

-- DimCategories
CREATE TABLE DimCategories AS
SELECT DISTINCT
    CategoryID,
    CategoryName,
    Description
FROM categories_staging;

-- DimTime
WITH DateGenerator AS (
    SELECT DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '2000-01-01') AS DateKey
    FROM TABLE(GENERATOR(ROWCOUNT => 11323))
)
CREATE TABLE DimTime AS
SELECT 
    DateKey,
    DateKey AS FullDate,
    YEAR(DateKey) AS Year,
    CEIL(MONTH(DateKey) / 3.0) AS Quarter,
    MONTH(DateKey) AS Month,
    TO_CHAR(DateKey, 'Month') AS MonthName,
    DAY(DateKey) AS Day,
    TO_CHAR(DateKey, 'Day') AS DayName,
    WEEKOFYEAR(DateKey) AS WeekOfYear,
    CASE WHEN TO_CHAR(DateKey, 'Day') IN ('Saturday', 'Sunday') THEN TRUE ELSE FALSE END AS IsWeekend
FROM DateGenerator;

-- Faktová tabuľka FactOrders
CREATE TABLE FactOrders AS
SELECT 
    o.OrderID,
    od.ProductID,
    o.CustomerID,
    o.EmployeeID,
    o.ShipperID,
    o.OrderDate,
    od.Quantity,
    od.Quantity * p.Price AS TotalRevenue
FROM orders_staging o
JOIN orderdetails_staging od ON o.OrderID = od.OrderID
JOIN products_staging p ON od.ProductID = p.ProductID;

-- DROP staging tabuliek po transformácii
DROP TABLE IF EXISTS categories_staging;
DROP TABLE IF EXISTS customers_staging;
DROP TABLE IF EXISTS employees_staging;
DROP TABLE IF EXISTS shippers_staging;
DROP TABLE IF EXISTS products_staging;
DROP TABLE IF EXISTS suppliers_staging;
DROP TABLE IF EXISTS orders_staging;
DROP TABLE IF EXISTS orderdetails_staging;
