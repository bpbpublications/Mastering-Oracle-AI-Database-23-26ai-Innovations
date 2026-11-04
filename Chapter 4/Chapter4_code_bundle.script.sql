-- Create a blockchain table

create blockchain table software_licenses (
license_id 		number,
software_name 	varchar2(100),
license_key 	varchar2(255),
issued_date 	date,
expiration_date 	date,
constraint software_licenses_pk primary key (license_id)
)
no drop until 0 days idle
no delete until 16 days after insert
hashing using "SHA2_512"
with row version and user chain license_chain (software_name)
version "v2";


-- Checking the algorithm used by the blockchain table

set linesize 800
col SCHEMA_NAME for a15
col table_name for a30
col SCHEMA_NAME for a15
col HASH_ALGORITHM for a15

SELECT schema_name
       ,table_name
       ,hash_algorithm
FROM  dba_blockchain_tables 
WHERE table_name = 'SOFTWARE_LICENSES';


-- Use a data dictionary view to list all hidden columns present in the table

set linesize 800
col COLUMN_NAME for a60

SELECT column_name 
FROM dba_tab_cols 
WHERE table_name='SOFTWARE_LICENSES' 
AND hidden_column='YES';


-- Insert some data for software Oracle Database EE. We will insert two rows to test versioning and monitor chains:

insert into software_licenses(license_id, software_name, license_key, issued_date, expiration_date)
values (1,
'Oracle Database EE',
'ABCD-1234-EFGH-5678-IJKL',
to_date('2025-03-27', 'yyyy-mm-dd'),
to_date('2026-03-27', 'yyyy-mm-dd')),
(2,
'Microsoft Office 365',
'MSFT-5678-ZYXW-4321-QWER',
to_date('2025-01-15', 'yyyy-mm-dd'),
to_date('2026-01-15', 'yyyy-mm-dd')),
(3,
'Oracle Database EE',
'EFGH-5678-IKLM-9999-IJKL', 
to_date ('2025-03-27', 'yyyy-mm-dd'),
to_date ('2026-03-27', 'yyyy-mm-dd'))
);

commit;

-- We can see all the entries in the software_licenses blockchain table:

set linesize 800
     col SOFTWARE_NAME for a40
     col LICENSE_KEY for a30
     select * from software_licenses;

-- Check the latest version of each row in '_LAST$' 

set linesize 800
col SOFTWARE_NAME for a40
col LICENSE_KEY for a30

select * from software_licenses_last$;

-- Create a V1 table and compare the number of columns between the previously created V2 table and the new V1 tables through the following steps:

create blockchain table software_licenses_v1 (
license_id 		number,
software_name 	varchar2(100),
license_key 	varchar2(255),
issued_date 	date,
expiration_date 	date,
constraint software_licenses_v1_pk primary key (license_id)
)
no drop until 0 days idle
no delete until 16 days after insert
hashing using "SHA2_512"
version "v1";


-- Count the number of hidden columns for software_licenses table that was created as V2 

SELECT count(*)
FROM dba_tab_cols
WHERE table_name='SOFTWARE_LICENSES'
AND hidden_column='YES'; 


-- Check the number of hidden columns for software_licenses_v1 table

SELECT count(*)
FROM dba_tab_cols
WHERE table_name='SOFTWARE_LICENSES_V1'
AND hidden_column='YES'; 


-- To check the version of the blockchain table, run the following query:

set linesize 800
col table_name for a30
col table_version for a30
SELECT table_name,table_version  
FROM   dba_blockchain_tables 
WHERE  table_name in ('SOFTWARE_LICENSES_V1', 'SOFTWARE_LICENSES');


-- New initialization parameter


---- Create the test user named mk and grant role:

create user mk identified by mk1;
grant dba to mk;

---- Log in to the database as mk user:

sqlplus mk/mk1@mk23ai:1521/ORCLPDB1


---- Attempt to create a blockchain table with an extended idle retention period results in error:


create blockchain table my_products(
  id            number,
  name         varchar2(20),
  quantity      number,
  expiration_date  date,
  constraint my_products_pk primary key (id)
)
no drop until 17 days idle
no delete until 16 days after insert
hashing using "SHA2_512" version "v2";


---- Granting the TABLE RETENTION privilege to the user

grant table retention to mk;

---- Once the privilege is granted, the user can successfully create the blockchain table

create blockchain table my_products(
  id            number,
  name         varchar2(20),
  quantity      number,
  expiration_date  date,
  constraint my_products_pk primary key (id)
)
no drop until 17 days idle
no delete until 16 days after insert
hashing using "SHA2_512" version "v2";


-- Alter statement

alter table software_licenses_v1 add (description varchar2(150));

---- Attempting to drop a column also results in an error like the following:

alter table software_licenses_v1 drop column issued_date;

---- Selecting data from dba_blockchain_tables dictionary view and checking the column named table_version:

set linesize 800
col table_name for a30
col table_version for a30
SELECT table_name,table_version  
FROM   dba_blockchain_tables 
WHERE  table_name = 'SOFTWARE_LICENSES';


---- Adding a new column is successful on V2 table:

alter table software_licenses add (description varchar2(150));

---- We are also able to drop the column through the following command:

alter table software_licenses drop column description;

---- View the current column types for each table:

desc software_licenses_v1

desc software_licenses

---- Modify software_name column and extend the type for v1 and v2 tables:

alter table software_licenses_v1 modify (software_name varchar2(150));

alter table software_licenses modify (software_name varchar2(150));

-- Truncate statement

---- Truncate on V1 table ends with ORA-05715 error:

truncate table software_licenses_v1;

truncate table software_licenses;

-- Changes in SYS.DBMS_BLOCKCHAIN_TABLE package

---- Following is a sample PL/SQL block that demonstrates how to enable interval partitioning on a blockchain table:

BEGIN
  SYS.DBMS_BLOCKCHAIN_TABLE.ADD_INTERVAL_PARTITIONING(
    schema_name         => 'SYS',
    table_name          => 'SOFTWARE_LICENSES',
    interval_number     => 1,
    interval_frequency  => 'MONTH',
    first_high_timestamp => TO_TIMESTAMP('2024-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')
  );
END;
/


---- Check the value column from v$option data dictionary view:

SELECT * FROM v$option 
WHERE parameter = 'Partitioning';


---- Shut down the database: Connect as sysdba and shutdown the target database:

shut immediate;

---- Enable partitioning: To enable the partitioning feature, run the following commands as the Oracle user:

cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk part_on
make -f ins_rdbms.mk ioracle

---- Start up the database: 

startup;

---- Confirm partitioning is enabled

SELECT * 
     FROM v$option 
     WHERE parameter = 'Partitioning';

---- Let us now verify that the table has been partitioned by selecting dba_tables and checking the column named partitioned:

col table_name for a30
SELECT table_name, partitioned 
FROM dba_tables 
WHERE table_name='SOFTWARE_LICENSES';

-- Blockchain tables for tamper-proof Flashback Data Archive

---- Connect to the database as sysdba user and create a new test user named demo_user and grant db_developer_role:

CREATE USER demo_user IDENTIFIED BY demo_password;
GRANT db_developer_role TO demo_user;


---- Set up a tablespace and flashback data archive. We will create a dedicated tablespace and associate it with a new FDA:

CREATE TABLESPACE archive_ts 
DATAFILE SIZE 10M 
AUTOEXTEND ON NEXT 1M;

CREATE FLASHBACK ARCHIVE DEFAULT secure_archive
TABLESPACE archive_ts
QUOTA 5G
RETENTION 2 YEAR;

---- Grant necessary permissions. 

ALTER USER demo_user QUOTA UNLIMITED ON archive_ts;
GRANT FLASHBACK ARCHIVE ON secure_archive TO demo_user;
GRANT CREATE ANY CONTEXT TO demo_user;
GRANT EXECUTE ON DBMS_FLASHBACK_ARCHIVE TO demo_user;
GRANT FLASHBACK ARCHIVE ADMINISTER TO demo_user;

---- Create a table with blockchain-enabled FDA

CREATE TABLE audit_log (
  log_id        NUMBER,
  action_type   VARCHAR2(100),
  log_date      DATE,
  CONSTRAINT audit_log_pk PRIMARY KEY (log_id)
)
BLOCKCHAIN FLASHBACK ARCHIVE secure_archive;



