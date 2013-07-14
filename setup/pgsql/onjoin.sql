CREATE TABLE onjoin (
    nick VARCHAR(20) NOT NULL,
    channel VARCHAR(30) NOT NULL,
    message VARCHAR(255) NOT NULL,
    modified_by VARCHAR(20) DEFAULT 'nobody' NOT NULL,
    modified_time numeric DEFAULT 0 NOT NULL
) WITHOUT OIDS;

REVOKE ALL ON TABLE onjoin FROM PUBLIC;

ALTER TABLE ONLY onjoin
    ADD CONSTRAINT onjoin_pkey PRIMARY KEY (nick, channel);
