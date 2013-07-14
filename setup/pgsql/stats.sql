CREATE TABLE stats (
    nick VARCHAR(20) NOT NULL,
    "type" VARCHAR(8) NOT NULL,
    channel VARCHAR(30) DEFAULT 'PRIVATE' NOT NULL,
    "time" numeric DEFAULT 0 NOT NULL,
    counter numeric DEFAULT 0
) WITHOUT OIDS;

REVOKE ALL ON TABLE stats FROM PUBLIC;

ALTER TABLE ONLY stats
    ADD CONSTRAINT stats_pkey PRIMARY KEY (nick, "type", channel);
