CREATE TABLE factoids (
 factoid_key VARCHAR(64) NOT NULL,
 requested_by VARCHAR(100) DEFAULT NULL,
 requested_time INT DEFAULT NULL,
 requested_count SMALLINT UNSIGNED NOT NULL DEFAULT '0',
 created_by VARCHAR(100) DEFAULT NULL,
 created_time INT DEFAULT NULL,
 modified_by VARCHAR(100) DEFAULT NULL,
 modified_time INT DEFAULT NULL,
 locked_by VARCHAR(100) DEFAULT NULL,
 locked_time INT DEFAULT NULL,
 factoid_value TEXT NOT NULL,
 PRIMARY KEY (factoid_key)
);
