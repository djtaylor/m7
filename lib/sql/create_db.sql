-- M7 Cluster Database
--
-- This database is designed to keep track of the nodes in the M7 distributed
-- testing platform. Test results are not stored here.

CREATE TABLE IF NOT EXISTS M7_Nodes ( 
	Id INTEGER PRIMARY KEY AUTOINCREMENT, 
	Name VARCHAR(25) NOT NULL,
	`Type` VARCHAR(10) NOT NULL, 
	IPAddr VARCHAR(12) NOT NULL, 
	SSHPort INTEGER NOT NULL, 
	User VARCHAR(60) NOT NULL,
	Hostname VARCHAR(60) NOT NULL,
	Region VARCHAR(60),
	Modified DEFAULT CURRENT_TIMESTAMP 
);