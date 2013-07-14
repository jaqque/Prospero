CREATE TABLE botmail (
    srcwho character varying(20) NOT NULL,
    dstwho character varying(20) NOT NULL,
    srcuh character varying(80) NOT NULL,
    "time" numeric DEFAULT 0 NOT NULL,
    msg text NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE botmail FROM PUBLIC;

ALTER TABLE ONLY botmail
    ADD CONSTRAINT botmail_pkey PRIMARY KEY (srcwho, dstwho);
