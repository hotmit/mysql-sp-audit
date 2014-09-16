DELIMITER $$
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