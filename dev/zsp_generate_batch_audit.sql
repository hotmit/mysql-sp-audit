-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- Copyright (c) 2014 Du T. Dang. MIT License
-- https://github.com/hotmit/mysql-sp-audit
-- --------------------------------------------------------------------

DELIMITER $$

DROP PROCEDURE IF EXISTS `zsp_generate_batch_audit`
$$

CREATE PROCEDURE `zsp_generate_batch_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_names VARCHAR(255), OUT out_script LONGTEXT, OUT out_error_msgs LONGTEXT)
main_block: BEGIN

	DECLARE s, e, scripts, error_msgs LONGTEXT;
	DECLARE audit_table_name VARCHAR(255);
	DECLARE done INT DEFAULT FALSE;
	DECLARE cursor_table_list CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
		WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE' 
			AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
			AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0;

	DECLARE CONTINUE HANDLER
		FOR NOT FOUND SET done = TRUE;

	SET scripts := '';
	SET error_msgs := '';

	OPEN cursor_table_list;

	cur_loop: LOOP
		FETCH cursor_table_list INTO audit_table_name;

		IF done THEN
			LEAVE cur_loop;
		END IF;

		CALL zsp_generate_audit(audit_schema_name, audit_table_name, s, e);

		SET scripts := CONCAT( scripts, '\n\n', IFNULL(s, '') );
		SET error_msgs := CONCAT( error_msgs, '\n\n', IFNULL(e, '') );

	END LOOP;

	CLOSE cursor_table_list;

	SET out_script := scripts;
	SET out_error_msgs := error_msgs;
END
$$