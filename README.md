*Failsafe IT
Databasen lagrar kunder, konsulter och deras uppdrag. Öppna failsafe_it.sql i SSMS och kör skriptet i en tom SQL Server-databas. ER-diagrammet finns i ER-diagram.png.

** Nomralisering
-	1NF. Varje fält innehåller ett värde och varje uppdrag har en egen rad. 
-	2NF. Varje kandidatnyckel består av en enda kolumn, så inga attribut beror på bara en del av nyckel.
-	3NF. Kunduppgifter lagras i Kund och konsultuppgifter i Konsult. Uppdrag referar till båda tabellerna med främmande nyclar.
*** DevSecOps
-Sec. Jag använder parametriserade frågor för värden från webbformulär och ger appens databaskonto bara de behörigheter det behöver. 
-Ops. Det unika indexet på Organisationsnummer underlättar kundsökning. Indexet på Uppdrag som börjar med KundId hjälper uppslag av kundens uppdrag.
