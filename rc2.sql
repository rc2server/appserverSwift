--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.3
-- Dumped by pg_dump version 9.6.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET search_path = public, pg_catalog;

ALTER TABLE IF EXISTS ONLY public.sessionrecord DROP CONSTRAINT IF EXISTS sessionrecord_wspace_fk;
ALTER TABLE IF EXISTS ONLY public.sessionimage DROP CONSTRAINT IF EXISTS sessionimage_sessionrec_fk;
ALTER TABLE IF EXISTS ONLY public.rcworkspacedata DROP CONSTRAINT IF EXISTS rcworkspacedata_id_fkey;
ALTER TABLE IF EXISTS ONLY public.rcworkspace DROP CONSTRAINT IF EXISTS rcworkspace_projectid_fkey;
ALTER TABLE IF EXISTS ONLY public.rcproject DROP CONSTRAINT IF EXISTS rcproject_userid_fkey;
ALTER TABLE IF EXISTS ONLY public.rcfiledata DROP CONSTRAINT IF EXISTS rcfiledata_file_fk;
ALTER TABLE IF EXISTS ONLY public.rcfile DROP CONSTRAINT IF EXISTS rcfile_wspaceid_fkey;
ALTER TABLE IF EXISTS ONLY public.logintoken DROP CONSTRAINT IF EXISTS logintoken_userid_fkey;
DROP TRIGGER IF EXISTS rcworkspace_update_version ON public.rcworkspace;
DROP TRIGGER IF EXISTS rcworkspace_update_lastmod ON public.rcworkspace;
DROP TRIGGER IF EXISTS rcuser_update_version ON public.rcuser;
DROP TRIGGER IF EXISTS rcuser_update_lastmod ON public.rcuser;
DROP TRIGGER IF EXISTS rcproject_update_version ON public.rcproject;
DROP TRIGGER IF EXISTS rcproject_update_lastmod ON public.rcproject;
DROP TRIGGER IF EXISTS rcfile_trigger_notifyu ON public.rcfile;
DROP TRIGGER IF EXISTS rcfile_trigger_notifyi ON public.rcfile;
DROP TRIGGER IF EXISTS rcfile_trigger_notifyd ON public.rcfile;
DROP INDEX IF EXISTS public.sessionimage_sessionrec_idx;
DROP INDEX IF EXISTS public.rcuser_login_idx;
DROP INDEX IF EXISTS public.rcuser_email_idx;
ALTER TABLE IF EXISTS ONLY public.sessionrecord DROP CONSTRAINT IF EXISTS sessionrecord_pkey;
ALTER TABLE IF EXISTS ONLY public.sessionimage DROP CONSTRAINT IF EXISTS sessionimage_pkey;
ALTER TABLE IF EXISTS ONLY public.rcworkspacedata DROP CONSTRAINT IF EXISTS rcworkspacedata_pkey;
ALTER TABLE IF EXISTS ONLY public.rcworkspace DROP CONSTRAINT IF EXISTS rcworkspace_uniqueid_key;
ALTER TABLE IF EXISTS ONLY public.rcworkspace DROP CONSTRAINT IF EXISTS rcworkspace_pkey;
ALTER TABLE IF EXISTS ONLY public.rcuser DROP CONSTRAINT IF EXISTS rcuser_pkey;
ALTER TABLE IF EXISTS ONLY public.rcuser DROP CONSTRAINT IF EXISTS rcuser_login_unique;
ALTER TABLE IF EXISTS ONLY public.rcproject DROP CONSTRAINT IF EXISTS rcproject_pkey;
ALTER TABLE IF EXISTS ONLY public.rcfiledata DROP CONSTRAINT IF EXISTS rcfiledata_pkey;
ALTER TABLE IF EXISTS ONLY public.rcfile DROP CONSTRAINT IF EXISTS rcfile_pkey;
ALTER TABLE IF EXISTS ONLY public.metadata DROP CONSTRAINT IF EXISTS metadata_pkey;
ALTER TABLE IF EXISTS ONLY public.logintoken DROP CONSTRAINT IF EXISTS logintoken_pkey;
DROP TABLE IF EXISTS public.sessionrecord;
DROP SEQUENCE IF EXISTS public.sessionrecord_seq;
DROP TABLE IF EXISTS public.sessionimage;
DROP SEQUENCE IF EXISTS public.sessionimage_seq;
DROP TABLE IF EXISTS public.rcworkspacedata;
DROP TABLE IF EXISTS public.rcworkspace;
DROP SEQUENCE IF EXISTS public.rcworkspace_seq;
DROP TABLE IF EXISTS public.rcuser;
DROP SEQUENCE IF EXISTS public.rcuser_seq;
DROP TABLE IF EXISTS public.rcproject;
DROP SEQUENCE IF EXISTS public.rcproject_seq;
DROP TABLE IF EXISTS public.rcfiledata;
DROP TABLE IF EXISTS public.rcfile;
DROP SEQUENCE IF EXISTS public.rcfile_seq;
DROP TABLE IF EXISTS public.metadata;
DROP TABLE IF EXISTS public.logintoken;
DROP SEQUENCE IF EXISTS public.logintoken_seq;
DROP FUNCTION IF EXISTS public.update_version_column();
DROP FUNCTION IF EXISTS public.update_lastmodified_column();
DROP FUNCTION IF EXISTS public.rcfile_notifyu();
DROP FUNCTION IF EXISTS public.rcfile_notifyi();
DROP FUNCTION IF EXISTS public.rcfile_notifyd();
DROP FUNCTION IF EXISTS public.rc2createuser(login character varying, fname character varying, lname character varying, email character varying, password character varying);
DROP EXTENSION IF EXISTS pgcrypto;
DROP EXTENSION IF EXISTS plpgsql;
DROP SCHEMA IF EXISTS public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: rc2createuser(character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rc2createuser(login character varying, fname character varying, lname character varying, email character varying, password character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
userId integer;
projectId integer;
BEGIN
INSERT INTO rcuser (login, firstname, lastname, email, passworddata) VALUES
(login, fname, lname, email, crypt(password, gen_salt('bf', 8))) RETURNING id INTO userId;
INSERT INTO rcproject (userid, name) VALUES (userId, 'default') RETURNING ID INTO projectId;
INSERT INTO rcworkspace (userid, projectid, name) VALUES (userId, projectId, 'default');
RETURN userId;
END;
$$;


--
-- Name: rcfile_notifyd(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcfile_notifyd() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
perform pg_notify(cast('rcfile' as text), 'd' || cast(old.id as text) || '/' || cast(old.wspaceid as text) || '/' || cast(old.version as text));
return new;
END;
$$;


--
-- Name: rcfile_notifyi(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcfile_notifyi() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
perform pg_notify(cast('rcfile' as text), 'i' || cast(new.id as text) || '/' || cast(new.wspaceid as text) || '/' || cast(new.version as text));
return new;
END;
$$;


--
-- Name: rcfile_notifyu(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcfile_notifyu() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
perform pg_notify(cast('rcfile' as text), 'u' || cast(old.id as text) || '/' || cast(old.wspaceid as text) || '/' || cast(old.version as text));
return new;
END;
$$;


--
-- Name: update_lastmodified_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION update_lastmodified_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   NEW.lastmodified = now(); 
   RETURN NEW;
END;
$$;


--
-- Name: update_version_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION update_version_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   NEW.version = NEW.version + 1; 
   RETURN NEW;
END;
$$;


--
-- Name: logintoken_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE logintoken_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: logintoken; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE logintoken (
    id integer DEFAULT nextval('logintoken_seq'::regclass) NOT NULL,
    userid integer NOT NULL,
    datecreated timestamp without time zone DEFAULT now() NOT NULL,
    valid boolean DEFAULT true NOT NULL
);


--
-- Name: metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE metadata (
    key character varying(200) NOT NULL,
    valuestr character(200),
    valueint integer
);


--
-- Name: rcfile_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rcfile_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rcfile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rcfile (
    id integer DEFAULT nextval('rcfile_seq'::regclass) NOT NULL,
    wspaceid integer NOT NULL,
    name character varying(200) NOT NULL,
    datecreated timestamp without time zone DEFAULT now() NOT NULL,
    lastmodified timestamp without time zone DEFAULT now() NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    filesize integer
);


--
-- Name: rcfiledata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rcfiledata (
    id integer NOT NULL,
    bindata bytea
);


--
-- Name: rcproject_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rcproject_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rcproject; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rcproject (
    id integer DEFAULT nextval('rcproject_seq'::regclass) NOT NULL,
    name character varying(60) NOT NULL,
    userid integer NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    datecreated timestamp without time zone DEFAULT now() NOT NULL,
    lastaccess timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rcuser_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rcuser_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rcuser; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rcuser (
    id integer DEFAULT nextval('rcuser_seq'::regclass) NOT NULL,
    login character varying(40) NOT NULL,
    firstname character varying(20),
    lastname character varying(20),
    email character varying(80) NOT NULL,
    passworddata character varying(200),
    admin boolean DEFAULT false NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    lastmodified timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rcworkspace_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rcworkspace_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rcworkspace; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rcworkspace (
    id integer DEFAULT nextval('rcworkspace_seq'::regclass) NOT NULL,
    name character varying(60) NOT NULL,
    userid integer NOT NULL,
    projectid integer NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    lastaccess timestamp without time zone DEFAULT now() NOT NULL,
    datecreated timestamp without time zone DEFAULT now() NOT NULL,
    uniqueid character(36) DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: rcworkspacedata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rcworkspacedata (
    id integer NOT NULL,
    bindata bytea
);


--
-- Name: sessionimage_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sessionimage_seq
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessionimage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sessionimage (
    id integer DEFAULT nextval('sessionimage_seq'::regclass) NOT NULL,
    sessionid integer NOT NULL,
    batchid integer DEFAULT 0 NOT NULL,
    name character varying(80) NOT NULL,
    title character varying(255),
    datecreated timestamp without time zone DEFAULT now() NOT NULL,
    imgdata bytea
);


--
-- Name: sessionrecord_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sessionrecord_seq
    START WITH 10
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessionrecord; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sessionrecord (
    id integer DEFAULT nextval('sessionrecord_seq'::regclass) NOT NULL,
    wspaceid integer NOT NULL,
    startdate timestamp without time zone DEFAULT now() NOT NULL,
    enddate timestamp without time zone
);


--
-- Name: logintoken logintoken_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY logintoken
    ADD CONSTRAINT logintoken_pkey PRIMARY KEY (id);


--
-- Name: metadata metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY metadata
    ADD CONSTRAINT metadata_pkey PRIMARY KEY (key);


--
-- Name: rcfile rcfile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcfile
    ADD CONSTRAINT rcfile_pkey PRIMARY KEY (id);


--
-- Name: rcfiledata rcfiledata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcfiledata
    ADD CONSTRAINT rcfiledata_pkey PRIMARY KEY (id);


--
-- Name: rcproject rcproject_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcproject
    ADD CONSTRAINT rcproject_pkey PRIMARY KEY (id);


--
-- Name: rcuser rcuser_login_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcuser
    ADD CONSTRAINT rcuser_login_unique UNIQUE (login);


--
-- Name: rcuser rcuser_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcuser
    ADD CONSTRAINT rcuser_pkey PRIMARY KEY (id);


--
-- Name: rcworkspace rcworkspace_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcworkspace
    ADD CONSTRAINT rcworkspace_pkey PRIMARY KEY (id);


--
-- Name: rcworkspace rcworkspace_uniqueid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcworkspace
    ADD CONSTRAINT rcworkspace_uniqueid_key UNIQUE (uniqueid);


--
-- Name: rcworkspacedata rcworkspacedata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcworkspacedata
    ADD CONSTRAINT rcworkspacedata_pkey PRIMARY KEY (id);


--
-- Name: sessionimage sessionimage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessionimage
    ADD CONSTRAINT sessionimage_pkey PRIMARY KEY (id);


--
-- Name: sessionrecord sessionrecord_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessionrecord
    ADD CONSTRAINT sessionrecord_pkey PRIMARY KEY (id);


--
-- Name: rcuser_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rcuser_email_idx ON rcuser USING btree (email);


--
-- Name: rcuser_login_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rcuser_login_idx ON rcuser USING btree (login);


--
-- Name: sessionimage_sessionrec_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessionimage_sessionrec_idx ON sessionimage USING btree (sessionid);


--
-- Name: rcfile rcfile_trigger_notifyd; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcfile_trigger_notifyd AFTER DELETE ON rcfile FOR EACH ROW EXECUTE PROCEDURE rcfile_notifyd();


--
-- Name: rcfile rcfile_trigger_notifyi; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcfile_trigger_notifyi AFTER INSERT ON rcfile FOR EACH ROW EXECUTE PROCEDURE rcfile_notifyi();


--
-- Name: rcfile rcfile_trigger_notifyu; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcfile_trigger_notifyu AFTER UPDATE ON rcfile FOR EACH ROW EXECUTE PROCEDURE rcfile_notifyu();


--
-- Name: rcproject rcproject_update_lastmod; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcproject_update_lastmod BEFORE UPDATE ON rcproject FOR EACH ROW EXECUTE PROCEDURE update_lastmodified_column();


--
-- Name: rcproject rcproject_update_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcproject_update_version BEFORE UPDATE ON rcproject FOR EACH ROW EXECUTE PROCEDURE update_version_column();


--
-- Name: rcuser rcuser_update_lastmod; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcuser_update_lastmod BEFORE UPDATE ON rcuser FOR EACH ROW EXECUTE PROCEDURE update_lastmodified_column();


--
-- Name: rcuser rcuser_update_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcuser_update_version BEFORE UPDATE ON rcuser FOR EACH ROW EXECUTE PROCEDURE update_version_column();


--
-- Name: rcworkspace rcworkspace_update_lastmod; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcworkspace_update_lastmod BEFORE UPDATE ON rcworkspace FOR EACH ROW EXECUTE PROCEDURE update_lastmodified_column();


--
-- Name: rcworkspace rcworkspace_update_version; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rcworkspace_update_version BEFORE UPDATE ON rcworkspace FOR EACH ROW EXECUTE PROCEDURE update_version_column();


--
-- Name: logintoken logintoken_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY logintoken
    ADD CONSTRAINT logintoken_userid_fkey FOREIGN KEY (userid) REFERENCES rcuser(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: rcfile rcfile_wspaceid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcfile
    ADD CONSTRAINT rcfile_wspaceid_fkey FOREIGN KEY (wspaceid) REFERENCES rcworkspace(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: rcfiledata rcfiledata_file_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcfiledata
    ADD CONSTRAINT rcfiledata_file_fk FOREIGN KEY (id) REFERENCES rcfile(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: rcproject rcproject_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcproject
    ADD CONSTRAINT rcproject_userid_fkey FOREIGN KEY (userid) REFERENCES rcuser(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: rcworkspace rcworkspace_projectid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcworkspace
    ADD CONSTRAINT rcworkspace_projectid_fkey FOREIGN KEY (projectid) REFERENCES rcproject(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: rcworkspacedata rcworkspacedata_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rcworkspacedata
    ADD CONSTRAINT rcworkspacedata_id_fkey FOREIGN KEY (id) REFERENCES rcworkspace(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: sessionimage sessionimage_sessionrec_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessionimage
    ADD CONSTRAINT sessionimage_sessionrec_fk FOREIGN KEY (sessionid) REFERENCES sessionrecord(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: sessionrecord sessionrecord_wspace_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessionrecord
    ADD CONSTRAINT sessionrecord_wspace_fk FOREIGN KEY (wspaceid) REFERENCES rcworkspace(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- PostgreSQL database dump complete
--

