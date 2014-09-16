-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- Copyright (c) 2014 Du T. Dang. MIT License
-- https://github.com/hotmit/mysql-sp-audit
-- --------------------------------------------------------------------

DELIMITER $$

DROP PROCEDURE IF EXISTS `zsp_generate_batch_audit`
$$

CREATE PROCEDURE `zsp_generate_batch_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_names VARCHAR(255), OUT script LONGTEXT, OUT errors LONGTEXT)
main_block: BEGIN

	DECLARE script, out_errors, stmt, error_msg LONGTEXT;
	DECLARE audit_table_name VARCHAR(255);
	DECLARE done INT DEFAULT FALSE;
	DECLARE cursor_table_list CURSOR FOR ( SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
		WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE' 
			AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
			AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0 );

	DECLARE CONTINUE HANDLER
		FOR NOT FOUND SET done = 1;

	SET script := '';
	SET out_erros := '';

	OPEN cursor_table_list;

	cur_loop: LOOP
		FETCH cursor_table_list INTO audit_table_name;		

		IF done THEN
			LEAVE cur_loop;
		END IF;



		SET script := CONCAT( script, '\n\n', stmt );
		SET out_errors := CONCAT( out_errors, '\n\n', error_msg );

	END LOOP;

	CLOSE cursor_table_list;

	SELECT script, out_errors AS `ERRORS`;
END
$$