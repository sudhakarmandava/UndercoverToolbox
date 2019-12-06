--Undercover Catalogue Compatability Patch (0.4.0 revision)
--David Fowler 
--06/12/2019
--Please note that we don't support the Catalogue on versions of SQL prior to SQL2012.  
--This patch is provided as is and unsupported.


--populate ConfigModules
INSERT INTO Catalogue.ConfigModules (ModuleName,GetProcName,UpdateProcName,StageTableName,MainTableName,Active)
VALUES ('Databases2008','GetDatabases2008','UpdateDatabases2008','Databases_Stage','Databases',0)

--Get module ID
DECLARE @ModuleID INT
SELECT @ModuleID = ID
FROM Catalogue.ConfigModules
WHERE ModuleName = 'Databases2008'



INSERT INTO Catalogue.ConfigModulesDefinitions ([ModuleID],Online,GetDefinition,UpdateDefinition,GetURL,UpdateURL)
VALUES (@ModuleID,1,
'
--Undercover Catalogue
--David Fowler
--Version 0.4.0 - 25 November 2019
--Module: Databases (2008 Compatibility)
--Script: Update

BEGIN

--get all databases on server

SELECT	@@SERVERNAME AS ServerName,
		databases.name AS DBName,
		databases.database_id AS DatabaseID,
		server_principals.name AS OwnerName,
		databases.compatibility_level AS CompatibilityLevel,
		databases.collation_name AS CollationName,
		databases.recovery_model_desc AS RecoveryModelDesc,
		NULL AS AGName,
		files.FilePaths,
		files.DatabaseSizeMB
FROM sys.databases
LEFT OUTER JOIN sys.server_principals ON server_principals.sid = databases.owner_sid
--LEFT OUTER JOIN sys.availability_replicas ON availability_replicas.replica_id = databases.replica_id
--LEFT OUTER JOIN sys.availability_groups ON availability_groups.group_id = availability_replicas.group_id
JOIN	(SELECT database_id, (SUM(CAST (size AS BIGINT)) * 8)/1024 AS DatabaseSizeMB,STUFF((SELECT '', '' + files2.physical_name
				FROM sys.master_files files2
				WHERE files2.database_id = files1.database_id
				FOR XML PATH('''')
			), 1, 2, '''') AS FilePaths
		FROM sys.master_files files1
		GROUP BY database_id) files ON files.database_id = databases.database_id
END',
'--Undercover Catalogue
--David Fowler
--Version 0.4.0 - 25 November 2019
--Module: Databases (2008 Compatibility)
--Script: Update


BEGIN

--update databases where they are known to the catalogue
UPDATE Catalogue.Databases 
SET		ServerName = Databases_Stage.ServerName,
		DBName = Databases_Stage.DBName,
		DatabaseID = Databases_Stage.DatabaseID,
		OwnerName = Databases_Stage.OwnerName,
		CompatibilityLevel = Databases_Stage.CompatibilityLevel,
		CollationName = Databases_Stage.CollationName,
		RecoveryModelDesc = Databases_Stage.RecoveryModelDesc,
		AGName = Databases_Stage.AGName,
		FilePaths = Databases_Stage.FilePaths,
		DatabaseSizeMB= Databases_Stage.DatabaseSizeMB,
		LastRecorded = GETDATE(),
		StateDesc = Databases_Stage.StateDesc
FROM Catalogue.Databases_Stage
WHERE	Databases.ServerName = Databases_Stage.ServerName
		AND Databases.DBName = Databases_Stage.DBName

--insert jobs that are unknown to the catlogue
INSERT INTO Catalogue.Databases
(ServerName, DBName, DatabaseID, OwnerName, CompatibilityLevel, CollationName, RecoveryModelDesc, AGName,FilePaths,DatabaseSizeMB,FirstRecorded,LastRecorded, StateDesc)
SELECT ServerName,
		DBName,
		DatabaseID,
		OwnerName,
		CompatibilityLevel,
		CollationName,
		RecoveryModelDesc,
		AGName,
		FilePaths,
		DatabaseSizeMB,
		GETDATE(),
		GETDATE(),
		StateDesc
FROM Catalogue.Databases_Stage
WHERE NOT EXISTS 
(SELECT 1 FROM Catalogue.Databases
		WHERE DBName = Databases_Stage.DBName
		AND Databases.ServerName = Databases_Stage.ServerName)

END',
'https://raw.githubusercontent.com/SQLUndercover/UndercoverToolbox/Catalogue-v0.4-dev/SQLUndercoverCatalogue/ModuleDefinitions/GetDatabases2008.sql',
'https://raw.githubusercontent.com/SQLUndercover/UndercoverToolbox/Catalogue-v0.4-dev/SQLUndercoverCatalogue/ModuleDefinitions/UpdateDatabases2008.sql'
)
