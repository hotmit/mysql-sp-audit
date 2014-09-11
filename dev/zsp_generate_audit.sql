-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- Copyright (c) 2014 MIT License
-- https://github.com/hotmit/mysql-sp-audit
-- --------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `zsp_generate_audit`;
DELIMITER $$

CREATE PROCEDURE `zsp_generate_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_name VARCHAR(255))
main_block: BEGIN

	DECLARE trg_insert, trg_update, trg_delete, vw_audit, vw_audit_meta LONGTEXT;
	DECLARE stmt, header LONGTEXT;
	DECLARE at_id1, at_id2 LONGTEXT;

	-- TODO: check audit and meta table, exists of table provided, check trigger/view existence


	-- Default max length of GROUP_CONCAT IS 1024
	SET SESSION group_concat_max_len = 100000;

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

	-- TODO: check at least one id exist

	-- LEAVE main_block;

	SET header := CONCAT( 
		'-- --------------------------------------------------------------------\n',
		'-- MySQL Audit Trigger\n',
		'-- Copyright (c) 2014 MIT License\n',
		'-- https://github.com/hotmit/mysql-sp-audit\n',
		'-- --------------------------------------------------------------------\n\n'		
	);

	
	SET trg_insert := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_AINS`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`', audit_table_name, '_AINS` AFTER INSERT ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
	SET trg_update := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_AUPD`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`', audit_table_name, '_AUPD` AFTER UPDATE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
	SET trg_delete := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_ADEL`\n$$\n',
						'CREATE TRIGGER `', audit_schema_name, '`.`', audit_table_name, '_ADEL` AFTER DELETE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );

	SET stmt := 'DECLARE zaudit_last_inserted_id BIGINT(20);\n\n';
	SET trg_insert := CONCAT( trg_insert, stmt );
	SET trg_update := CONCAT( trg_update, stmt );
	SET trg_delete := CONCAT( trg_delete, stmt );


	-- ----------------------------------------------------------
	-- [ Create Insert Statement Into Audit & Audit Meta Tables ]
	-- ----------------------------------------------------------

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE (@zaudit_user, ', 
		'''', audit_table_name, ''', ', 'NEW.`', at_id1, '`, ', IFNULL( CONCAT('NEW.`', at_id2, '`, ') , '') );

	SET trg_insert := CONCAT( trg_insert, stmt, '''INSERT''); \n\n');

	SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.zaudit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE (@zaudit_user, ', 
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

	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', NULL, ',						
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN 'HEX(' ELSE '' END,
							'NEW.`', COLUMN_NAME, '`', ') ' ,
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN ')' ELSE '' END,
						','
					SEPARATOR '\n') 
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
							AND BINARY TABLE_NAME = BINARY audit_table_name );

	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_insert := CONCAT( trg_insert, stmt );


	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', ', 
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN 'HEX(' ELSE '' END,
							'OLD.`', COLUMN_NAME, '`', 
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN ')' ELSE '' END,
						', ',
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN 'HEX(' ELSE '' END,
							'NEW.`', COLUMN_NAME, '`', ') ' ,
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN ')' ELSE '' END,
						','
					SEPARATOR '\n') 
					FROM information_schema.columns
						WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name 
							AND BINARY TABLE_NAME = BINARY audit_table_name );

	SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND\n$$' );
	SET trg_update := CONCAT( trg_update, stmt );


	SET stmt := ( SELECT GROUP_CONCAT('   (zaudit_last_inserted_id, ''', COLUMN_NAME, ''', ', 
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN 'HEX(' ELSE '' END,
							'OLD.`', COLUMN_NAME, '`', 
						CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN ')' ELSE '' END,
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

	SELECT stmt AS `Audit Script`;

END
