-- -------------------------------------------------------------------- 
-- MySQL Audit Trigger 
-- Copyright (c) 2014 Du T. Dang. MIT License 
-- https://github.com/hotmit/mysql-sp-audit 
-- Version: v1.0
-- Build Date: Wed, 22 Oct 2014 16:42:08 GMT
-- -------------------------------------------------------------------- 

DELIMITER $$

DROP TABLE IF EXISTS `zaudit`
$$
CREATE TABLE `zaudit` (
  `audit_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(255) DEFAULT NULL,
  `table_name` varchar(255) DEFAULT NULL,
  `pk1` varchar(255) DEFAULT NULL,
  `pk2` varchar(255) DEFAULT NULL,
  `action` varchar(6) DEFAULT NULL COMMENT 'Values: insert|update|delete',
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`audit_id`),
  KEY `pk_index` (`table_name`,`pk1`,`pk2`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;

$$
DROP TABLE IF EXISTS `zaudit_meta`
$$
CREATE TABLE `zaudit_meta` (
  `audit_meta_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `audit_id` bigint(20) unsigned NOT NULL,
  `col_name` varchar(255) NOT NULL,
  `old_value` longtext DEFAULT NULL,
  `new_value` longtext DEFAULT NULL,
  PRIMARY KEY (`audit_meta_id`),
  KEY `zaudit_meta_index` (`audit_id`,`col_name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;

$$

DROP PROCEDURE IF EXISTS `zsp_generate_audit`;
$$

CREATE PROCEDURE `zsp_generate_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_name VARCHAR(255), OUT script LONGTEXT, OUT errors LONGTEXT)
main_block: BEGIN

	DECLARE trg_insert, trg_update, trg_delete, vw_audit, vw_audit_meta, out_errors LONGTEXT;
	DECLARE stmt, header LONGTEXT;
	DECLARE at_id1, at_id2 LONGTEXT;
	DECLARE c INTEGER;

	-- Default max length of GROUP_CONCAT IS 1024
	SET SESSION group_concat_max_len = 100000;

	SET out_errors := '';

	-- Check to see if the specified table exists
	SET c := (SELECT COUNT(*) FROM information_schema.tables
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
				AND BINARY table_name = BINARY audit_table_name);
	IF c <> 1 THEN
		SET out_errors := CONCAT( out_errors, '\n', 'The table you specified `', audit_schema_name, '`.`', audit_table_name, '` does not exists.' );
		LEAVE main_block;
	END IF;


	-- Check audit and meta table exists
	SET c := (SELECT COUNT(*) FROM information_schema.tables
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
				AND (BINARY table_name = BINARY 'zaudit' OR BINARY table_name = BINARY 'zaudit_meta') );
	IF c <> 2 THEN
		SET out_errors := CONCAT( out_errors, '\n', 'Audit table structure do not exists, please check or run the audit setup script again.' );
	END IF;


	-- Check triggers exists
	SET c := ( SELECT GROUP_CONCAT( TRIGGER_NAME SEPARATOR ', ') FROM information_schema.triggers
			WHERE BINARY EVENT_OBJECT_SCHEMA = BINARY audit_schema_name 
				AND BINARY EVENT_OBJECT_TABLE = BINARY audit_table_name 
				AND BINARY ACTION_TIMING = BINARY 'AFTER' AND BINARY TRIGGER_NAME NOT LIKE BINARY CONCAT('z', audit_table_name, '_%') GROUP BY EVENT_OBJECT_TABLE );
	IF c IS NOT NULL AND LENGTH(c) > 0 THEN
		SET out_errors := CONCAT( out_errors, '\n', 'MySQL 5 only supports one trigger per insert/update/delete action. Currently there are these triggers (', c, ') already assigned to `', audit_schema_name, '`.`', audit_table_name, '`. You must remove them before the audit trigger can be applied' );
	END IF;

	

	-- Get the first primary key 
	SET at_id1 := (SELECT COLUMN_NAME FROM information_schema.columns
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
				AND BINARY table_name = BINARY audit_table_name
			AND column_key = 'PRI' LIMIT 1);

	-- Get the second primary key 
	SET at_id2 := (SELECT COLUMN_NAME FROM information_schema.columns
			WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
				AND BINARY table_name = BINARY audit_table_name
			AND column_key = 'PRI' LIMIT 1,1);

	-- Check at least one id exists
	IF at_id1 IS NULL AND at_id2 IS NULL THEN 
		SET out_errors := CONCAT( out_errors, '\n', 'The table you specified `', audit_schema_name, '`.`', audit_table_name, '` does not have any primary key.' );
	END IF;



	SET header := CONCAT( 
		'-- --------------------------------------------------------------------\n',
		'-- MySQL Audit Trigger\n',
		'-- Copyright (c) 2014 Du T. Dang. MIT License\n',
		'-- https://github.com/hotmit/mysql-sp-audit\n',
		'-- --------------------------------------------------------------------\n\n'		
	);

	
	SET trg_insert := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AINS`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`z', audit_table_name, '_AINS` AFTER INSERT ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
	SET trg_update := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AUPD`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`z', audit_table_name, '_AUPD` AFTER UPDATE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
	SET trg_delete := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_ADEL`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`z', audit_table_name, '_ADEL` AFTER DELETE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );

	SET stmt := 'DECLARE zaudit_last_inserted_id BIGINT(20);\n\n';
	SET trg_insert := CONCAT( trg_insert, stmt );
	SET trg_update := CONCAT( trg_update, stmt );
	SET trg_delete := CONCAT( trg_delete, stmt );


	-- ----------------------------------------------------------
	-- [ Create Insert Statement Into Audit & Audit Meta Tables ]
	-- ----------------------------------------------------------

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE ( IFNULL( @zaudit_user, USER() ), ', 
		'''', audit_table_name, ''', ', 'NEW.`', at_id1, '`, ', IFNULL( CONCAT('NEW.`', at_id2, '`, ') , '') );

	SET trg_insert := CONCAT( trg_insert, stmt, '''INSERT''); \n\n');

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE ( IFNULL( @zaudit_user, USER() ), ', 
		'''', audit_table_name, ''', ', 'OLD.`', at_id1, '`, ', IFNULL( CONCAT('OLD.`', at_id2, '`, ') , '') );

	SET trg_update := CONCAT( trg_update, stmt, '''UPDATE''); \n\n' );
	SET trg_delete := CONCAT( trg_delete, stmt, '''DELETE''); \n\n' );


	SET stmt := 'SET zaudit_last_inserted_id = LAST_INSERT_ID();\n';
	SET trg_insert := CONCAT( trg_insert, stmt );
	SET trg_update := CONCAT( trg_update, stmt );
	SET trg_delete := CONCAT( trg_delete, stmt );
	
	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit_meta (audit_id, col_name, old_value, new_value) VALUES \n' );
	SET trg_insert := CONCAT( trg_insert, '\n', stmt );
	SET trg_update := CONCAT( trg_update, '\n', stmt );
	SET trg_delete := CONCAT( trg_delete, '\n', stmt );

	SET stmt := ( SELECT GROUP_CONCAT(' (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', NULL, ',	
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN 
							'''[UNSUPPORTED BINARY DATATYPE]''' 
						ELSE 						
							CONCAT('NEW.`', COLUMN_NAME, '`')
						END,
						'),'
					SEPARATOR '\n')
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
							AND BINARY TABLE_NAME = BINARY audit_table_name );

	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_insert := CONCAT( trg_insert, stmt );



	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', ', 
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
							'''[SAME]'''
						ELSE
							CONCAT('OLD.`', COLUMN_NAME, '`')
						END,
						', ',
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
							CONCAT('CASE WHEN BINARY OLD.`', COLUMN_NAME, '` <=> BINARY NEW.`', COLUMN_NAME, '` THEN ''[SAME]'' ELSE ''[CHANGED]'' END')
						ELSE
							CONCAT('NEW.`', COLUMN_NAME, '`')
						END,
						'),'
					SEPARATOR '\n') 
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
							AND BINARY TABLE_NAME = BINARY audit_table_name );

	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_update := CONCAT( trg_update, stmt );



	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', ', 
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN 
							'''[UNSUPPORTED BINARY DATATYPE]''' 
						ELSE 						
							CONCAT('OLD.`', COLUMN_NAME, '`')
						END,
						', NULL ),'
					SEPARATOR '\n') 
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
							AND BINARY TABLE_NAME = BINARY audit_table_name );


	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_delete := CONCAT( trg_delete, stmt );

	-- -----------------------------------------------
	-- [ Generating Helper Views For The Audit Table ] 
	-- -----------------------------------------------
	SET stmt := CONCAT( 'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '_meta`\n$$\n',
						'CREATE VIEW `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '_meta` AS \n', header,
						'SELECT za.audit_id, zm.audit_meta_id, za.user, \n',
						'	za.pk1, za.pk2,\n',
						'	za.action, zm.col_name, zm.old_value, zm.new_value, za.timestamp\n',
						'FROM `', audit_schema_name, '`.zaudit za \n', 
						'INNER JOIN `', audit_schema_name, '`.zaudit_meta zm ON za.audit_id = zm.audit_id \n',
						'WHERE za.table_name = ''', audit_table_name, '''');

	SET vw_audit_meta := CONCAT( stmt, '$$' );


	SET stmt := ( SELECT GROUP_CONCAT( 	'		MAX((CASE WHEN zm.col_name = ''', COLUMN_NAME, ''' THEN zm.old_value ELSE NULL END)) AS `', COLUMN_NAME, '_old`, \n',
										'		MAX((CASE WHEN zm.col_name = ''', COLUMN_NAME, ''' THEN zm.new_value ELSE NULL END)) AS `', COLUMN_NAME, '_new`, \n' 
						SEPARATOR '\n') 
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
							AND BINARY TABLE_NAME = BINARY audit_table_name 
				);
	SET stmt := TRIM( TRAILING ', \n' FROM stmt );		
	SET stmt := ( SELECT CONCAT( 	'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '`\n$$\n',
									'CREATE VIEW `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '` AS \n', header,
									'SELECT za.audit_id, za.user, za.pk1, za.pk2,\n', 
									'za.action, za.timestamp, \n', 
									stmt , '\n',
									'	FROM `', audit_schema_name, '`.zaudit za \n', 
									'	INNER JOIN `', audit_schema_name, '`.zaudit_meta zm ON za.audit_id = zm.audit_id \n'
									'WHERE za.table_name = ''', audit_table_name, '''\n',
									'GROUP BY zm.audit_id') );

	SET vw_audit := CONCAT( stmt, '\n$$' );


	-- SELECT trg_insert, trg_update, trg_delete, vw_audit, vw_audit_meta;

	SET stmt = CONCAT( 
		'-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n',
		'-- --------------------------------------------------------------------\n',
		'-- Audit Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
		'-- Date Generated: ', NOW(), '\n',
		'-- Generated By: ', CURRENT_USER(), '\n',
		'-- BEGIN\n',
		'-- --------------------------------------------------------------------\n\n'	
		'DELIMITER $$',
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Insert Trigger Code ]\n',		
		'-- -----------------------------------------------------------\n',
		trg_insert,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Update Trigger Code ]\n',
		'-- -----------------------------------------------------------\n',
		trg_update,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Delete Trigger Code ]\n',		
		'-- -----------------------------------------------------------\n',
		trg_delete,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` Audit Meta View ]\n',		
		'-- -----------------------------------------------------------\n',
		vw_audit_meta,
		'\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` Audit View ]\n',		
		'-- -----------------------------------------------------------\n',
		vw_audit,
		'\n\n',
		'-- --------------------------------------------------------------------\n',
		'-- END\n',
		'-- Audit Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',		
		'-- --------------------------------------------------------------------\n\n',
		'-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n'
		);

	-- SELECT stmt AS `Audit Script`, out_errors AS `ERRORS`;

	SET script := stmt;
	SET errors := out_errors;
END
$$

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

DROP PROCEDURE IF EXISTS `zsp_generate_remove_audit`
$$

CREATE PROCEDURE `zsp_generate_remove_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_name VARCHAR(255), OUT script LONGTEXT)
main_block: BEGIN

	SET script := CONCAT(
		'-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n',
		'-- --------------------------------------------------------------------\n',
		'-- Audit Removal Script For `',audit_schema_name, '`.`', audit_table_name, '` \n',
		'-- Date Generated: ', NOW(), '\n',
		'-- Generated By: ', CURRENT_USER(), '\n',
		'-- BEGIN\n',
		'-- --------------------------------------------------------------------\n\n', 
		'DELIMITER $$\n\n',

		'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AINS`\n$$\n',
		'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_AUPD`\n$$\n',
		'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`z', audit_table_name, '_ADEL`\n$$\n',

		'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '_meta`\n$$\n',
		'DROP VIEW IF EXISTS `', audit_schema_name, '`.`zvw_audit_', audit_table_name, '`\n$$\n',

		'\n\n',
		'-- --------------------------------------------------------------------\n',
		'-- END\n',
		'-- Audit Removal Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',		
		'-- --------------------------------------------------------------------\n\n',
		'-- $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n'
	);

END
$$

DROP PROCEDURE IF EXISTS `zsp_generate_batch_remove_audit`
$$

CREATE PROCEDURE `zsp_generate_batch_remove_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_names VARCHAR(255), OUT out_script LONGTEXT)
main_block: BEGIN

	DECLARE s, scripts LONGTEXT;
	DECLARE audit_table_name VARCHAR(255);
	DECLARE done INT DEFAULT FALSE;
	DECLARE cursor_table_list CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
		WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE' 
			AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
			AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0;

	DECLARE CONTINUE HANDLER
		FOR NOT FOUND SET done = TRUE;

	SET scripts := '';

	OPEN cursor_table_list;

	cur_loop: LOOP
		FETCH cursor_table_list INTO audit_table_name;

		IF done THEN
			LEAVE cur_loop;
		END IF;

		CALL zsp_generate_remove_audit(audit_schema_name, audit_table_name, s);

		SET scripts := CONCAT( scripts, '\n\n', IFNULL(s, '') );

	END LOOP;

	CLOSE cursor_table_list;

	SET out_script := scripts;
END
$$