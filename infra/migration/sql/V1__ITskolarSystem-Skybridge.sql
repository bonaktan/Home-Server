-- ITskolar-System (https://github.com/PUP-ITskolar/ITskolar-System) 

CREATE USER "ITskolar-System_Admin";
CREATE USER "ITskolar-System_Worker";
CREATE DATABASE ITskolar_System;

ALTER USER "ITskolar-System_Admin"  WITH NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
ALTER USER "ITskolar-System_Worker" WITH NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

ALTER USER "ITskolar-System_Worker" CONNECTION LIMIT 20;
ALTER ROLE "ITskolar-System_Worker" SET statement_timeout = '30s';
ALTER ROLE "ITskolar-System_Worker" SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE "ITskolar-System_Admin"  SET statement_timeout = '5min';

REVOKE ALL ON DATABASE ITskolar_System FROM PUBLIC;

-- REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- REVOKE EXECUTE ON FUNCTION pg_read_file(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION pg_read_file(text, bigint, bigint) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION pg_read_binary_file(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION pg_ls_dir(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION lo_import(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION lo_export(oid, text) FROM PUBLIC;

-- GRANT ALL PRIVILEGES ON DATABASE ITskolar_System TO "ITskolar-System_Admin";
-- GRANT ALL PRIVILEGES ON SCHEMA public TO "ITskolar-System_Admin";
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "ITskolar-System_Admin";
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "ITskolar-System_Admin";
-- GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "ITskolar-System_Admin";

-- ALTER DEFAULT PRIVILEGES FOR ROLE "ITskolar-System_Admin" IN SCHEMA public
--   GRANT ALL PRIVILEGES ON TABLES TO "ITskolar-System_Admin";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "ITskolar-System_Admin" IN SCHEMA public
--   GRANT ALL PRIVILEGES ON SEQUENCES TO "ITskolar-System_Admin";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "ITskolar-System_Admin" IN SCHEMA public
--   GRANT ALL PRIVILEGES ON FUNCTIONS TO "ITskolar-System_Admin";

-- GRANT CONNECT ON DATABASE ITskolar_System TO "ITskolar-System_Worker";
-- GRANT USAGE ON SCHEMA public TO "ITskolar-System_Worker";
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "ITskolar-System_Worker";
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "ITskolar-System_Worker";

-- ALTER DEFAULT PRIVILEGES FOR ROLE "ITskolar-System_Admin" IN SCHEMA public
--   GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "ITskolar-System_Worker";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "ITskolar-System_Admin" IN SCHEMA public
--   GRANT USAGE, SELECT ON SEQUENCES TO "ITskolar-System_Worker";

-- START TRANSACTION;

-- CREATE SCHEMA application;
-- ALTER SCHEMA application OWNER TO "ITskolar-System_Admin";
-- COMMENT ON SCHEMA application IS 'Specific to ITskolarSystem/Dashboard';

-- CREATE SCHEMA student;
-- ALTER SCHEMA student OWNER TO "ITskolar-System_Admin";
-- COMMENT ON SCHEMA application IS 'Specific to IRL Data (Student-Centric)';

-- CREATE TABLE student.student (
--     student_id character(15) NOT NULL PRIMARY KEY,
--     last_name character varying(50) NOT NULL,
--     first_name character varying(50) NOT NULL,
--     middle_name character varying(50),
--     birthday date NOT NULL,
--     nickname character varying(10)[],
--     active boolean DEFAULT true NOT NULL
-- );
-- ALTER TABLE student.student OWNER TO "ITskolar-System_Admin";
-- COMMENT ON TABLE student.student IS 'Students Registered in BSIT Batch 2029';

-- CREATE TABLE student.subjects (
--     course_id character varying(8) NOT NULL PRIMARY KEY,
--     course_name character varying(64) NOT NULL,
--     active boolean DEFAULT true
-- );
-- ALTER TABLE student.student OWNER TO "ITskolar-System_Admin";
-- COMMENT ON TABLE student.student IS 'Subjects Enrolled by Students';

-- CREATE TABLE application.bot_users (
--     discord_id bigint NOT NULL PRIMARY KEY,
--     student_id character(15) NOT NULL REFERENCES student.student(student_id),
--     username character varying(32) NOT NULL,
--     nickname character varying(32) NOT NULL
-- );
-- ALTER TABLE application.bot_users OWNER TO "ITskolar-System_Admin";
-- COMMENT ON TABLE application.bot_users IS 'Discord Data of Users';

-- CREATE TABLE application.otp (
--     service character varying(16) NOT NULL,
--     key character(32) NOT NULL PRIMARY KEY
-- );
-- ALTER TABLE application.otp OWNER TO "ITskolar-System_Admin";
-- COMMENT ON TABLE application.otp IS 'OTP Keys for ITskolar Accounts';

-- CREATE TABLE application.resources (
--     resource_id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
--     course_id character varying(8) NOT NULL REFERENCES student.subjects(course_id),
--     name character varying(128) NOT NULL,
--     date date NOT NULL,
--     description text,
--     file_path text,
--     file_hash character(32),
--     pending_upload boolean,
-- 	CONSTRAINT unique_file_uploaded UNIQUE NULLS NOT DISTINCT (file_path, file_hash)
-- );
-- ALTER TABLE application.resources OWNER TO "ITskolar-System_Admin";
-- COMMENT ON TABLE application.resources IS 'Documents uploaded in resources.itskolarngbayan.xyz';

-- CREATE TABLE application.sticky (
--     message_id bigint NOT NULL PRIMARY KEY,
--     channel_id bigint NOT NULL,
--     message text NOT NULL,
--     active boolean DEFAULT true NOT NULL
-- );
-- ALTER TABLE application.sticky OWNER TO "ITskolar-System_Admin";
-- COMMENT ON TABLE application.sticky IS 'Sticky Messages set in ITskolarBot';

-- REVOKE ALL ON TABLE application.bot_users FROM "ITskolar-System_Worker";
-- GRANT SELECT,INSERT,UPDATE ON TABLE application.bot_users TO "ITskolar-System_Worker";

-- REVOKE ALL ON TABLE application.otp FROM "ITskolar-System_Worker";
-- GRANT SELECT ON TABLE application.otp TO "ITskolar-System_Worker";

-- REVOKE ALL ON TABLE application.resources FROM "ITskolar-System_Worker";
-- GRANT SELECT,INSERT,UPDATE ON TABLE application.resources TO "ITskolar-System_Worker";

-- REVOKE ALL ON TABLE application.sticky FROM "ITskolar-System_Worker";
-- GRANT SELECT,INSERT,UPDATE ON TABLE application.sticky TO "ITskolar-System_Worker";

-- REVOKE ALL ON TABLE student.student FROM "ITskolar-System_Worker";
-- GRANT SELECT ON TABLE student.student TO "ITskolar-System_Worker";

-- REVOKE ALL ON TABLE student.subjects FROM "ITskolar-System_Worker";
-- GRANT SELECT ON TABLE student.subjects TO "ITskolar-System_Worker";

-- COMMIT;
-- Skybridge Airways (https://github.com/bonaktan/Skybridge-Airways)

CREATE USER "Skybridge-Airways_Admin";
CREATE USER "Skybridge-Airways_Worker";
CREATE DATABASE Skybridge_Airways;

ALTER USER "Skybridge-Airways_Admin"  WITH NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
ALTER USER "Skybridge-Airways_Worker" WITH NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

ALTER USER "Skybridge-Airways_Worker" CONNECTION LIMIT 20;
ALTER ROLE "Skybridge-Airways_Worker" SET statement_timeout = '30s';
ALTER ROLE "Skybridge-Airways_Worker" SET idle_in_transaction_session_timeout = '60s';
ALTER ROLE "Skybridge-Airways_Admin"  SET statement_timeout = '5min';

REVOKE ALL ON DATABASE Skybridge_Airways FROM PUBLIC;

-- REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- REVOKE EXECUTE ON FUNCTION pg_read_file(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION pg_read_file(text, bigint, bigint) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION pg_read_binary_file(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION pg_ls_dir(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION lo_import(text) FROM PUBLIC;
-- REVOKE EXECUTE ON FUNCTION lo_export(oid, text) FROM PUBLIC;

-- GRANT ALL PRIVILEGES ON DATABASE Skybridge_Airways TO "Skybridge-Airways_Admin";
-- GRANT ALL PRIVILEGES ON SCHEMA public TO "Skybridge-Airways_Admin";
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "Skybridge-Airways_Admin";
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "Skybridge-Airways_Admin";
-- GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "Skybridge-Airways_Admin";

-- ALTER DEFAULT PRIVILEGES FOR ROLE "Skybridge-Airways_Admin" IN SCHEMA public
--   GRANT ALL PRIVILEGES ON TABLES TO "Skybridge-Airways_Admin";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "Skybridge-Airways_Admin" IN SCHEMA public
--   GRANT ALL PRIVILEGES ON SEQUENCES TO "Skybridge-Airways_Admin";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "Skybridge-Airways_Admin" IN SCHEMA public
--   GRANT ALL PRIVILEGES ON FUNCTIONS TO "Skybridge-Airways_Admin";

-- GRANT CONNECT ON DATABASE Skybridge_Airways TO "Skybridge-Airways_Worker";
-- GRANT USAGE ON SCHEMA public TO "Skybridge-Airways_Worker";
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "Skybridge-Airways_Worker";
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "Skybridge-Airways_Worker";

-- ALTER DEFAULT PRIVILEGES FOR ROLE "Skybridge-Airways_Admin" IN SCHEMA public
--   GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "Skybridge-Airways_Worker";
-- ALTER DEFAULT PRIVILEGES FOR ROLE "Skybridge-Airways_Admin" IN SCHEMA public
--   GRANT USAGE, SELECT ON SEQUENCES TO "Skybridge-Airways_Worker";
