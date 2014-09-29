## MySQL Audit (mysql-sp-audit)
Using trigger based stored procedure to create audit table. It follows the word press meta data approach to store the changes, so all the data is stores in just two centralized tables.

---
## MySQL Component Requirements
I put the requirement here so in case you want to run this in a lower version of mysql, you'll know where to change.

* v5.x         Trigger support
* v5.0.10   INFORMATION_SCHEMA.TRIGGERS
* v5.0.32   DROP ... IF EXISTS

* v5.6.1     Base64 (not yet implemented)

---
## Usage
1. Run 'mysql_sp_audit_setup.sql' script. 
	* This will create:
		a. `zaudit` and `zaudit_meta tables` (the tables that hold the data for all the audits)
		a. Stored procedures:
			* zsp_generate_audit: generates audit script for one table
			* zsp_generate_batch_audit: generates a script for multiple table at a time
			* zsp_generate_remove_audit: generates the script to remove audit from one table
			* zsp_generate_batch_remove_audit: generates a script for multiple table at a time
1. To Enable the audit on the table you want.
	* zsp_generate_audit( @audit_schema_name, @audit_table_name, OUT @script, OUT @errors )
		* ie. zsp_generate_audit( 'your_db_name', 'contact', @output_script, @output_errors)
	* Copy the value from @output_script and run it
		* Now you should see three triggers and 2 new views on the contact table
			* Triggers: zcontact_AINS, zcontact_AUPD, and zcontact_ADEL
			* Views: zvw_audit_contact and zvw_audit_contact_meta

---
## Features
* Using stored procedures to generate the audit setup and remove scripts
* The script will includes pre-generated views for easy access to the data
* Centralized audit data, everything is stored in two table (similar to wordpress meta)
* Allow the table's schemas to change, just need to rerun the stored procedure
      * Keep deleted columns data
* All values are stored as LONGTEXT therefore no blob support (as of now)
* Allow audit table up to 2 primary keys      


---
## Stored Procedures
* zsp_generate_audit( @audit_schema_name, @audit_table_name, OUT @script, OUT @errors )
      * Generate the audit script for one table
* zsp_generate_batch_audit ( @audit_schema_name, @audit_tables, OUT @script, OUT @errors )
      * Put the comma separated list of table names to generate a batch of audit scripts
* zsp_generate_remove_audit( @audit_schema_name, @audit_table_name, OUT @script )
      * Generate the script to remove the triggers and views
* zsp_generate_batch_remove_audit ( @audit_schema_name, @audit_tables, OUT @script)
      * Put the comma separated list of table names to generate a batch script that remove all the tables specified
	  
---
## Conflict
* Since MySQL 5 only allow one trigger per action, you have to merge your existing triggers with our audit trigger.
* If you already have a trigger on your table, this is how you resolve it:
	 * Copy the code for your trigger, then remove it 
	 * Run zsp_generate_audit()
	 * Edit the trigger and add the code you copied to the appropriate trigger	 

---
## Conventions
All names are prefixed with "z" to stay out of the way of your important stuff

##### Audit Table: zaudit

|audit_id  	|user |table_name |pk1  	|pk2  	|action  	|time-stamp  |
|---	|---	|---	|---	|---	|---	|---	|
|Auto-increment, one number for each change  	|User that made the change |The table name |First primary key  	|Second primary key  	|Insert, update or delete  	|Time the changed occurred  	|

##### Meta Table: zaudit_meta

|audit_meta_id  	|audit_id  	|col_name  	|old_value  	|new_value  	|
|---	|---	|---	|---	|---	|
|Auto-increment, one row for one value  	|Id from audit table  	|Name of the column  	|Old value  	|New value  	|

## Generated Views

##### View: zvw_audit_\<table_name\>_meta

|audit_id  	|audit_meta_id  	|user |pk1  	|pk2  	|action  	|col_name  	|old_value  	|new_value |time-stamp |
|---	|---	|---	|---	|---	|---	|---	|---	|---	|---	|
|Audit id  	|Meta id  	|User name/ user id |pk1  	|pk2  	|Insert, update or delete  	|Column name |Old value  	|New value |Date time  	|

##### View: zvw_audit_\<table_name\>

|audit_id  	|user |pk1  	|pk2  	|action  	|time-stamp |col1_old  	|col1_new  	|col2_old  	|col2_new|
|---	|---	|---	|---	|---	|---	|---	|---	|---	|---	|
|Audit id  	|User name/id |pk1  	|pk2  	|Insert, update, delete  	|Date time  	|Col1 old value  	|Col1 new value  	|Col2 old value  	|Col2 new value  	|


