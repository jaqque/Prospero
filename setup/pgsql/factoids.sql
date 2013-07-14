CREATE TABLE factoids (
    factoid_key VARCHAR(64) NOT NULL,
    requested_by VARCHAR(100) DEFAULT NULL,
    requested_time numeric(11) DEFAULT NULL,
    requested_count numeric(5) DEFAULT 0 NOT NULL,
    created_by VARCHAR(100) DEFAULT NULL,
    created_time numeric(11) DEFAULT NULL,
    modified_by VARCHAR(100) DEFAULT NULL,
    modified_time numeric(11) DEFAULT NULL,
    locked_by VARCHAR(100) DEFAULT NULL,
    locked_time numeric(11) DEFAULT NULL,
    factoid_value text NOT NULL
) WITHOUT OIDS;

CREATE INDEX factoids_idx_fvalue ON factoids USING hash (factoid_value);

ALTER TABLE ONLY factoids
    ADD CONSTRAINT factoids_pkey_fkey PRIMARY KEY (factoid_key);
