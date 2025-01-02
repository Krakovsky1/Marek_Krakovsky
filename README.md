# ETL proces datasetu Northwind

## 1. Úvod
Tento repozitár obsahuje implementáciu ETL procesu pre analýzu dát z Northwind datasetu. Cieľom je analyzovať predaj, efektivitu dodávateľov a správanie zákazníkov. Implementácia je postavená na Snowflake a používa dimenzionálny model typu hviezda..

## 2. Popis zdrojových dát
Cieľom semestrálneho projektu je analýza obchodných transakcií spoločnosti Northwind. 

Zdrojové dáta pochádzajú z Northwind datasetu dostupného na GitHub.com. Dataset obsahuje osem hlavných tabuliek:

- `Customers`: Informácie o zákazníkoch.
- `Orders`: Objednávky zákazníkov.
- `Shippers`: Odosielatelia.
- `Products`: Informácie o produktoch.
- `Categories`: Kategórie.
- `Employees`: Informácie o zamestnancoch.
- `Order Details`: Detaily objednávky.
- `Suppliers`: Dodávatelia.

Účelom ETL procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.

### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/Krakovsky1/Marek_Krakovsky/blob/main/Northwind_ERD%20(1).png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma Northwind</em>
</p>

---
## **3 Dimenzionálny model**

Navrhnutý bol **hviezdicový model (star schema)**, pre efektívnu analýzu kde centrálny bod predstavuje faktová tabuľka **`FactOrders`**, ktorá je prepojená s nasledujúcimi dimenziami:
- **`DimCategories`**: Obsahuje základné parametre ako názov kategórie a popis.
- **`DimEmployees`**: Obsahuje údaje o zamestnancoch ako sú ich meno, dátum narodenia a nejaké jednoduché poznámky.
- **`DimProducts`**: Zahrňuje informácie o názve produktu a o cene.
- **`DimShippers`**: Obsahuje len názov dodávateľa.
- **`DimTime`**: Obsahuje podrobné dátumové a časové údaje.
- **`DimCustomers`**: Obsahuje údaje o zákazníkovi.

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="https://github.com/Krakovsky1/Marek_Krakovsky/blob/main/starschema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre Northwind</em>
</p>

## **4. ETL proces v Snowflake**
ETL proces pozostával z troch hlavných fáz: `extrahovanie` (Extract), `transformácia` (Transform) a `načítanie` (Load). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **4.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu (formát `.csv`) boli najprv nahraté do Snowflake prostredníctvom interného stage úložiska s názvom `Northwind_stage`. Stage v Snowflake slúži ako dočasné úložisko na import alebo export dát. Vytvorenie stage bolo zabezpečené príkazom:

#### Príklad kódu:
```sql
CREATE OR REPLACE STAGE Northwind_stage;
```
Do stage boli následne nahraté súbory obsahujúce údaje o objednávkach, používateľoch, dodávateľoch, zamestnancoch... Dáta boli importované do staging tabuliek pomocou príkazu `COPY INTO`. Pre každú tabuľku sa použil podobný príkaz:

```sql
COPY INTO customers_staging
FROM @northwind_stage/customers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE'; 
```

V prípade nekonzistentných záznamov bol použitý parameter `ON_ERROR = 'CONTINUE'`, ktorý zabezpečil pokračovanie procesu bez prerušenia pri chybách.

---
### **4.2 (Transform) Transformácia dát**

V tejto fáze boli dáta zo staging tabuliek vyčistené, transformované a obohatené. Hlavným cieľom bolo pripraviť dimenzie a faktovú tabuľku, ktoré umožnia jednoduchú a efektívnu analýzu.

Dimenzie boli navrhnuté na poskytovanie kontextu pre faktovú tabuľku. `DimCustomers` obsahuje údaje o zákazníkoch vrátane mena, kontaktu, mesta a krajiny. Transformácia zahŕňala výber relevantných stĺpcov a úpravu štruktúry údajov na analýzu zákazníkov podľa regiónov a kontaktov.
```sql
INSERT INTO DimCustomers (CustomerID, CustomerName, ContactName, City, Country)
SELECT CustomerID, CustomerName, ContactName, City, Country
FROM customers_staging;
```

Podobne `DimEmployees` bola obohatená spojením mien zamestnancov do jedného atribútu:
```sql
INSERT INTO DimEmployees (EmployeeID, EmployeeName, BirthDate, Notes)
SELECT EmployeeID, CONCAT(FirstName, ' ', LastName) AS EmployeeName, BirthDate, Notes
FROM employees_staging;
```

Dimenzia `DimTime` bola navrhnutá tak, aby uchovávala informácie o časoch objednávok. Obsahuje odvodené údaje, ako sú deň, mesiac, rok, názov dňa a štvrťrok. Táto dimenzia umožňuje podrobné časové analýzy a je klasifikovaná ako SCD Typ 0, čo znamená, že údaje v nej zostávajú nemenné.
```sql
WITH DateGenerator AS (
    SELECT DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '2000-01-01') AS DateKey
    FROM TABLE(GENERATOR(ROWCOUNT => 11323))
)
INSERT INTO DimTime
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
```

Faktová tabuľka `FactOrders` bola vytvorená na zaznamenanie objednávok, produktov, zákazníkov, zamestnancov a dopravcov. Zahŕňa aj výpočet kľúčovej metriky `TotalRevenue`:
```sql
INSERT INTO FactOrders (OrderID, ProductID, CustomerID, EmployeeID, ShipperID, OrderDate, Quantity, TotalRevenue)
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
```
---

### **4.3 (Load) Načítanie dát**

Po úspešnom vytvorení dimenzií a faktovej tabuľky boli dáta nahraté do finálnej štruktúry. Na záver boli staging tabuľky odstránené, aby sa optimalizovalo využitie úložiska:
```sql
DROP TABLE IF EXISTS categories_staging;
DROP TABLE IF EXISTS customers_staging;
DROP TABLE IF EXISTS employees_staging;
DROP TABLE IF EXISTS shippers_staging;
DROP TABLE IF EXISTS products_staging;
DROP TABLE IF EXISTS suppliers_staging;
DROP TABLE IF EXISTS orders_staging;
DROP TABLE IF EXISTS orderdetails_staging;
```
ETL proces v Snowflake umožnil spracovanie pôvodných dát z `.csv` formátu do viacdimenzionálneho modelu typu hviezda. Tento proces zahŕňal čistenie, obohacovanie a reorganizáciu údajov. Výsledný model umožňuje analýzu obchodných transakcií, správania zákazníkov a efektivity zamestnancov, pričom poskytuje základ pre vizualizácie a reporty.

---
## **5 Vizualizácia dát**

Dashboard obsahuje `6 vizualizácií`, ktoré poskytujú základný prehľad o kľúčových metrikách a trendoch týkajúcich sa produktov, používateľov a objednávkach. Tieto vizualizácie odpovedajú na dôležité otázky a umožnujú zodpovedať rôzne otázky.

<p align="center">
  <img src="https://github.com/Krakovsky1/Marek_Krakovsky/blob/main/visualizations.png" alt="ERD Schema">
  <br>
  <em>Obrázok 3 Dashboard Northwind datasetu</em>
</p>

---
### **Graf 1: Výkonnosť zamestnancov**
Táto vizualizácia zobrazuje 10 kníh s najväčším počtom hodnotení. Umožňuje identifikovať najpopulárnejšie tituly medzi používateľmi. Zistíme napríklad, že kniha `Wild Animus` má výrazne viac hodnotení v porovnaní s ostatnými knihami. Tieto informácie môžu byť užitočné na odporúčanie kníh alebo marketingové kampane.

```sql
SELECT 
    e.EmployeeName AS "Zamestnanec",
    SUM(f.TotalRevenue) AS "Celkové tržby"
FROM FactOrders f
JOIN DimEmployees e ON f.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeName
ORDER BY "Celkové tržby" DESC;
```
---
### **Graf 2: Predaj podľa mesiacov**
Graf znázorňuje rozdiely v počte hodnotení medzi mužmi a ženami. Z údajov je zrejmé, že ženy hodnotili knihy o niečo častejšie ako muži, no rozdiely sú minimálne a aktivita medzi pohlaviami je viac-menej vyrovnaná. Táto vizualizácia ukazuje, že obsah alebo kampane môžu byť efektívne zamerané na obe pohlavia bez potreby výrazného rozlišovania.

```sql
SELECT 
    u.gender,
    COUNT(f.fact_ratingID) AS total_ratings
FROM FACT_RATINGS f
JOIN DIM_USERS u ON f.userID = u.dim_userId
GROUP BY u.gender;
```
---
### **Graf 3: Trendy hodnotení kníh podľa rokov vydania (2000–2024)**
Graf ukazuje, ako sa priemerné hodnotenie kníh mení podľa roku ich vydania v období 2000–2024. Z vizualizácie je vidieť, že medzi rokmi 2000 a 2005 si knihy udržiavali stabilné priemerné hodnotenie. Po tomto období však nastal výrazný pokles priemerného hodnotenia. Od tohto bodu opäť postupne stúpajú a  po roku 2020, je tendencia, že knihy získavajú vyššie priemerné hodnotenia. Tento trend môže naznačovať zmenu kvality kníh, vývoj čitateľských preferencií alebo rozdiely v hodnotiacich kritériách používateľov.

```sql
SELECT 
    b.release_year AS year,
    AVG(f.rating) AS avg_rating
FROM FACT_RATINGS f
JOIN DIM_BOOKS b ON f.bookID = b.dim_bookId
WHERE b.release_year BETWEEN 2000 AND 2024
GROUP BY b.release_year
ORDER BY b.release_year;
```
---
### **Graf 4: Celková aktivita počas dní v týždni**
Tabuľka znázorňuje, ako sú hodnotenia rozdelené podľa jednotlivých dní v týždni. Z údajov vyplýva, že najväčšia aktivita je zaznamenaná cez víkendy (sobota a nedeľa) a počas dní na prelome pracovného týždňa a víkendu (piatok a pondelok). Tento trend naznačuje, že používatelia majú viac času na čítanie a hodnotenie kníh počas voľných dní.

```sql
SELECT 
    d.dayOfWeekAsString AS day,
    COUNT(f.fact_ratingID) AS total_ratings
FROM FACT_RATINGS f
JOIN DIM_DATE d ON f.dateID = d.dim_dateID
GROUP BY d.dayOfWeekAsString
ORDER BY total_ratings DESC;
```
---
### **Graf 5: Počet hodnotení podľa povolaní**
Tento graf  poskytuje informácie o počte hodnotení podľa povolaní používateľov. Umožňuje analyzovať, ktoré profesijné skupiny sú najviac aktívne pri hodnotení kníh a ako môžu byť tieto skupiny zacielené pri vytváraní personalizovaných odporúčaní. Z údajov je zrejmé, že najaktívnejšími profesijnými skupinami sú `Marketing Specialists` a `Librarians`, s viac ako 1 miliónom hodnotení. 

```sql
SELECT 
    u.occupation AS occupation,
    COUNT(f.fact_ratingID) AS total_ratings
FROM FACT_RATINGS f
JOIN DIM_USERS u ON f.userID = u.dim_userId
GROUP BY u.occupation
ORDER BY total_ratings DESC
LIMIT 10;
```
---
### **Graf 6: Aktivita používateľov počas dňa podľa vekových kategórií**
Tento stĺpcový graf ukazuje, ako sa aktivita používateľov mení počas dňa (dopoludnia vs. popoludnia) a ako sa líši medzi rôznymi vekovými skupinami. Z grafu vyplýva, že používatelia vo vekovej kategórii `55+` sú aktívni rovnomerne počas celého dňa, zatiaľ čo ostatné vekové skupiny vykazujú výrazne nižšiu aktivitu a majú obmedzený čas na hodnotenie, čo môže súvisieť s pracovnými povinnosťami. Tieto informácie môžu pomôcť lepšie zacieliť obsah a plánovať aktivity pre rôzne vekové kategórie.
```sql
SELECT 
    t.ampm AS time_period,
    u.age_group AS age_group,
    COUNT(f.fact_ratingID) AS total_ratings
FROM FACT_RATINGS f
JOIN DIM_TIME t ON f.timeID = t.dim_timeID
JOIN DIM_USERS u ON f.userID = u.dim_userId
GROUP BY t.ampm, u.age_group
ORDER BY time_period, total_ratings DESC;

```

Dashboard poskytuje komplexný pohľad na dáta, pričom zodpovedá dôležité otázky týkajúce sa čitateľských preferencií a správania používateľov. Vizualizácie umožňujú jednoduchú interpretáciu dát a môžu byť využité na optimalizáciu odporúčacích systémov, marketingových stratégií a knižničných služieb.

---

**Autor:** Janka Pecuchová
