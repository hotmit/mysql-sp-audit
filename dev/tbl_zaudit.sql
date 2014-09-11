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
  `old_value` longtext,
  `new_value` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`audit_meta_id`),
  KEY `zaudit_meta_index` (`audit_id`,`col_name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;

$$
DROP TABLE IF EXISTS `multi_key`
$$
CREATE TABLE `multi_key` (
  `first_id` int(11) NOT NULL,
  `my second id` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `data` varchar(45) COLLATE utf8_unicode_ci DEFAULT NULL,
  `ME_BLOB` longblob,
  PRIMARY KEY (`first_id`,`my second id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

$$
DROP TABLE IF EXISTS `test_data`
$$

CREATE TABLE `test_data` (
  `my_id` int(10) unsigned NOT NULL,
  `str` varchar(45) COLLATE utf8_unicode_ci DEFAULT NULL,
  `num` float DEFAULT NULL,
  `dt` date DEFAULT NULL,
  `ts` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `image` longblob,
  PRIMARY KEY (`my_id`),
  KEY `col_index` (`str`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

$$