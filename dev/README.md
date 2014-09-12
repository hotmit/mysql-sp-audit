#### Dev Environment
* Import tbl_zaudit.sql to create audit structure and two test tables



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
