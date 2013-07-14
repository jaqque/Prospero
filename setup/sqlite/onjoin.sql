CREATE TABLE onjoin (
	nick VARCHAR(20) NOT NULL,
	channel VARCHAR(30) NOT NULL,
	message VARCHAR(255) NOT NULL,
	modified_by VARCHAR(20) NOT NULL DEFAULT 'nobody',
	modified_time INT NOT NULL DEFAULT '0',
	PRIMARY KEY (nick, channel)
);

-- v.2 -> v.3
-- ALTER TABLE onjoin ADD COLUMN modified_by VARCHAR(20) NOT NULL DEFAULT 'nobody';
-- ALTER TABLE onjoin ADD COLUMN modified_time INT NOT NULL DEFAULT '0';
-- ** the following doesn't work for sqlite **
-- ALTER TABLE onjoin ADD PRIMARY KEY (nick, channel);
