set stmt = (select 
    group_concat(COLUMN_NAME ORDER BY ORDINAL_POSITION ASC separator ', ')
from
    information_schema.columns
where
    table_name = 'test_data');

set stmt = concat_ws(' ', 'select', @stmt, 'from', 'test_data');
prepare sel_stmt from @stmt;
select @stmt;
execute sel_stmt;



set @key_count = (select count(*) from
    information_schema.columns
where
    table_name = 'test_data' and column_key = 'PRI');

select @key_count;



select * from
    information_schema.columns
where
    table_name = 'test_data';


select concat('aaa', null);
select concat(null, 'aaa');

SELECT DATABASE();




--  req v5.0.10 onwards
select * from 
	information_schema.TRIGGERS
where
    table_name = 'test_data';


SELECT * FROM information_schema.views;
SELECT * FROM information_schema.triggers;




 SELECT GROUP_CONCAT( TRIGGER_NAME SEPARATOR ', ') FROM information_schema.triggers
			WHERE  
				 ACTION_TIMING = 'AFTER' AND TRIGGER_NAME NOT LIKE CONCAT('z', 'test_data', '_%') GROUP BY EVENT_OBJECT_TABLE ;


SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
		WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE' 
			AND BINARY TABLE_SCHEMA = BINARY 'audit_dev'
			AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT('test_data', ',') ) > 0;












