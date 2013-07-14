CREATE TABLE rootwarn (
    nick VARCHAR(20) NOT NULL,
    attempt numeric,
    "time" numeric NOT NULL,
    host VARCHAR(80) NOT NULL,
    channel VARCHAR(30) NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE rootwarn FROM PUBLIC;

ALTER TABLE ONLY rootwarn
    ADD CONSTRAINT rootwarn_pkey PRIMARY KEY (nick);
