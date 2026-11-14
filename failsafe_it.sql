SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Kund', N'U') IS NOT NULL
	OR OBJECT_ID(N'dbo.Konsult', N'U') IS NOT NULL
	OR OBJECT_ID(N'dbo.Uppdrag', N'U') IS NOT NULL
	THROW 50001, N'Tabellerna finns redan. Välj en tom testdatabas.', 1;

BEGIN TRANSACTION;

--DDL - TABELLER, NYCKLAR OCH INDEX

CREATE TABLE dbo.Kund(
	KundId int IDENTITY(1,1) NOT NULL,
	Organisationsnummer char(11) NOT NULL,
	Foretagsnamn NVARCHAR(150) NOT NULL,
	Epost NVARCHAR(254) NOT NULL,
	Telefonnummer VARCHAR(25) NOT NULL,
	CONSTRAINT PK_Kund PRIMARY KEY (KundId),
	CONSTRAINT UQ_Kund_Organisationsnummer UNIQUE (Organisationsnummer));


CREATE TABLE dbo.Konsult (
	KonsultId int identity(1,1) NOT NULL,
	Personnummer char(13) NOT NULL,
	Namn NVARCHAR(150) NOT NULL,
	Timpris decimal(10,2) NOT NULL,
	Huvudspecialist NVARCHAR(100) NOT NULL,
	CONSTRAINT PK_Konsult PRIMARY KEY (konsultId),
	CONSTRAINT UQ_Konsult_Personnummer UNIQUE (Personnummer),
	CONSTRAINT CK_Konsult_Timpris CHECK (Timpris >= 0));


CREATE TABLE dbo.Uppdrag (
	UppdragId int IDENTITY(1,1) NOT NULL,
	KundId int NOT NULL,
	KonsultId int NOT NULL,
	Startdatum date NOT NULL,
	Slutdatum date NOT NULL,
	Rollbeskrivning nvarchar(255) NOT NULL,
	CONSTRAINT PK_Uppdrag PRIMARY KEY (UppdragId),
	CONSTRAINT FK_Uppdrag_Kund FOREIGN KEY (KundId)
		REFERENCES dbo.Kund (KundId) ON DELETE CASCADE,
	CONSTRAINT FK_Uppdrag_Konsult FOREIGN KEY (KonsultId)
		REFERENCES dbo.Konsult (KonsultId),
	CONSTRAINT CK_Uppdrag_Datum CHECK (Slutdatum >= Startdatum));


CREATE INDEX IX_Uppdrag_KundId_Slutdatum
	ON dbo.Uppdrag (KundId, Slutdatum) INCLUDE (Startdatum);

-- Testdata med datum

DECLARE @Idag date = CONVERT(date, GETDATE());

INSERT INTO dbo.Kund (Organisationsnummer, Foretagsnamn, Epost, Telefonnummer)
VALUES
	('559900-0100', N'Björkhamns Logistik AB', N'it@bjorkhamn.se', '031-3911611'),
	('559900-0200', N'Klarvik Energi AB', N'it@klarvik.se', '031-3900612'),
	('559900-0300', N'Ljunghäll Fastighet AB', N'i@ljunghall.com', '031-3900568'),
	('559900-0400', N'Solgläntans handel AB', N'it@solglantan.se', '031-3900574');

INSERT INTO dbo.Konsult (Personnummer, Namn, Timpris, Huvudspecialist)
VALUES 
	('19910514-1230', N'Martin Hansson', 1450.00, N'Cybersäkerhet'),
	('19881102-4561', N'Julia Sjödin', 1200.00, N'DevOps'),
	('19950327-7892', N'Mohammed Ibisevic', 1500.00, N'C#-Utveckling');

INSERT INTO dbo.Uppdrag (KundId, KonsultId, Startdatum, Slutdatum, Rollbeskrivning)
SELECT
	k.KundId,
	ko.KonsultId,
	DATEADD(day, t.Startdag, @Idag),
	DATEADD(day, t.Slutdag, @Idag),
	t.Rollbeskrivning

FROM (VALUES
	('559900-0100', '19910514-1230', -20, 20, N'Säkerhetsgransking av API-miljö'),
	('559900-0100', '19881102-4561', 0, 30, N'Automatisering av CI/CD'),
	('559900-0100', '19910514-1230', -85, -55, N'Genomgång av molnbehörigheter'),
	('559900-0200', '19950327-7892', -25, 0, N'Utveckling av ärende-API'),
	('559900-0200', '19881102-4561', 10, 50, N'Driftövervakning i Kubernetes'),
	('559900-0300', '19950327-7892', -70, -35, N'Integration mot fastighetssystem')
) AS t (Organisationsnummer, Personnummer, Startdag, Slutdag, Rollbeskrivning)
INNER JOIN dbo.Kund AS k ON k.Organisationsnummer = t.Organisationsnummer
INNER JOIN dbo.Konsult AS ko ON ko.Personnummer = t.Personnummer;

-- a - Konsulter med timpris över 1200 kr, dyrast först

SELECT Namn, Timpris
FROM dbo.Konsult
WHERE Timpris > 1200.00
ORDER BY Timpris DESC, Namn, KonsultId;

-- b - alla uppdrag med kundens och konsultens namn.
SELECT k.Foretagsnamn, ko.Namn AS Konsúltnamn, u.Startdatum, u.Slutdatum
FROM dbo.Uppdrag AS u
INNER JOIN dbo.Kund AS k ON k.KundId = u.KundId
INNER JOIN dbo.Konsult AS ko ON ko.KonsultId = u.KonsultId
ORDER BY u.Startdatum, u.UppdragId;

-- c - antal aktiva uppdrag per kund, överför kunder med noll.
SELECT k.Foretagsnamn, k.Organisationsnummer, COUNT(u.UppdragId) AS AntalAktivaUppdrag
FROM dbo.Kund AS k
LEFT JOIN dbo.Uppdrag AS u
	ON u.KundId = k.KundId
	AND u.Startdatum <= @Idag
	AND u.Slutdatum >= @Idag
GROUP BY k.Foretagsnamn, k.Organisationsnummer
ORDER BY k.Foretagsnamn, k.Organisationsnummer;

-- d - ändra timpriset för en konsult.

UPDATE dbo.Konsult
SET Timpris = 1275.00
OUTPUT inserted.Namn, deleted.Timpris AS TidigareTimpris, inserted.Timpris AS NyttTimpris
WHERE Personnummer = '19881102-4561';

-- e - radera kunden om den saknar uppdrag.
-- Lås kontrollen mot samtidiga ändringar tills transaktioen är klar.

DELETE k
OUTPUT deleted.Foretagsnamn, deleted.Organisationsnummer
FROM dbo.Kund AS k
WHERE k.Organisationsnummer = '559900-0300'
	AND NOT EXISTS (
		SELECT 1 
		FROM dbo.Uppdrag AS u WITH (UPDLOCK, HOLDLOCK)
		WHERE u.KundId = k.KundId
			AND u.Startdatum <= @Idag
			AND u.Slutdatum >= @Idag
	);

COMMIT TRANSACTION;