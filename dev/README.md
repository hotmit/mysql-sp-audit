#### Dev Environment
* Import tbl_zaudit.sql to create audit structure 
* Import tbl_test_tables.sql to create test_data and multi_key tables for testing

#### Build For Release
	* node build.js <release_version> [<--no-copyright>]

---
#### Useful Informations
```SQL
#Get all the columns detail
SELECT * FROM INFORMATION_SCHEMA.COLUMNS

#Get trigger info
SELECT * FROM INFORMATION_SCHEMA.TRIGGERS

#Combine multiple columns into a string
SELECT 
    GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION ASC SEPARATOR ', ')
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    TABLE_NAME = 'test_data'
	
```
