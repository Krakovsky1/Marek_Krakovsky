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
- `Dodávatelia`: Detaily objednávky.

Účelom ETL procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.

### **ERD diagram**
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na **entitno-relačnom diagrame (ERD)**:

<p align="center">
  <img src="https://github.com/Krakovsky1/Marek_Krakovsky/blob/main/projektFoto.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma Northwind</em>
</p>
