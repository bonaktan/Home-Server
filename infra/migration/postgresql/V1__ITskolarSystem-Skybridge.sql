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

-- BEGIN;

-- CREATE TABLE public.account (
--     id bigint NOT NULL,
--     account_name text NOT NULL,
--     email text NOT NULL,
--     password_hash text NOT NULL,
--     permissions jsonb DEFAULT '{}'::jsonb,
--     created_at timestamp with time zone DEFAULT now(),
--     updated_at timestamp with time zone DEFAULT now()
-- );
-- ALTER TABLE public.account OWNER TO "Skybridge-Airways_Admin";

-- CREATE SEQUENCE public.account_id_seq
--     START WITH 1
--     INCREMENT BY 1
--     NO MINVALUE
--     NO MAXVALUE
--     CACHE 1;
-- ALTER SEQUENCE public.account_id_seq OWNER TO "Skybridge-Airways_Admin";
-- ALTER SEQUENCE public.account_id_seq OWNED BY public.account.id;

-- CREATE TABLE public.airplane (
--     id text NOT NULL,
--     model text NOT NULL,
--     location text,
--     seatmap json DEFAULT '{}'::json NOT NULL,
--     seat_class json DEFAULT '{}'::json NOT NULL
-- );
-- ALTER TABLE public.airplane OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.airport (
--     name text NOT NULL,
--     id text NOT NULL,
--     capacity integer,
--     created_at timestamp with time zone DEFAULT now(),
--     country text DEFAULT 'blank'::text NOT NULL,
--     city text DEFAULT 'blank'::text NOT NULL,
--     CONSTRAINT airport_capacity_check CHECK ((capacity > 0))
-- );
-- ALTER TABLE public.airport OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.airport_flight (
--     airport_id text NOT NULL,
--     flight_id text NOT NULL,
--     relationship_type text NOT NULL
-- );
-- ALTER TABLE public.airport_flight OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.booking (
--     id bigint NOT NULL,
--     flight_id text NOT NULL,
--     account_id bigint,
--     payment_option text NOT NULL,
--     payment_detail jsonb NOT NULL,
--     booking_status text DEFAULT 'pending'::text,
--     created_at timestamp with time zone DEFAULT now(),
--     updated_at timestamp with time zone DEFAULT now(),
--     departure_date timestamp with time zone NOT NULL
-- );
-- ALTER TABLE public.booking OWNER TO "Skybridge-Airways_Admin";


-- CREATE SEQUENCE public.booking_id_seq
--     START WITH 1
--     INCREMENT BY 1
--     NO MINVALUE
--     NO MAXVALUE
--     CACHE 1;
-- ALTER SEQUENCE public.booking_id_seq OWNER TO "Skybridge-Airways_Admin";
-- ALTER SEQUENCE public.booking_id_seq OWNED BY public.booking.id;

-- CREATE TABLE public.booking_passenger (
--     booking_id bigint NOT NULL,
--     passenger_id bigint NOT NULL,
--     seat_id character varying(4) NOT NULL,
--     calculated_price numeric(10,2) NOT NULL,
--     CONSTRAINT booking_passenger_calculated_price_check CHECK ((calculated_price >= (0)::numeric))
-- );
-- ALTER TABLE public.booking_passenger OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.flight (
--     id text NOT NULL,
--     departure_airport_id text NOT NULL,
--     arrival_airport_id text NOT NULL,
--     base_ticket_price numeric(10,2) NOT NULL,
--     flight_time interval NOT NULL,
--     departure timestamp with time zone NOT NULL,
--     frequency interval NOT NULL,
--     created_at timestamp with time zone DEFAULT now(),
--     airplane_id text DEFAULT 'SB-W0001'::text NOT NULL,
--     CONSTRAINT flight_base_ticket_price_check CHECK ((base_ticket_price >= (0)::numeric)),
--     CONSTRAINT flight_check CHECK ((departure_airport_id <> arrival_airport_id))
-- );
-- ALTER TABLE public.flight OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.flight_staff (
--     flight_id text NOT NULL,
--     staff_id bigint NOT NULL
-- );
-- ALTER TABLE public.flight_staff OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.flyway_schema_history (
--     installed_rank integer NOT NULL,
--     version character varying(50),
--     description character varying(200) NOT NULL,
--     type character varying(20) NOT NULL,
--     script character varying(1000) NOT NULL,
--     checksum integer,
--     installed_by character varying(100) NOT NULL,
--     installed_on timestamp without time zone DEFAULT now() NOT NULL,
--     execution_time integer NOT NULL,
--     success boolean NOT NULL
-- );
-- ALTER TABLE public.flyway_schema_history OWNER TO "Skybridge-Airways_Admin";

-- CREATE TABLE public.passenger (
--     id bigint NOT NULL,
--     frequent_flyer_code text,
--     title text NOT NULL,
--     first_name text NOT NULL,
--     last_name text NOT NULL,
--     birthdate date NOT NULL,
--     contact_email text NOT NULL,
--     emergency_contact_name text NOT NULL,
--     associated_to bigint NOT NULL,
--     created_at timestamp with time zone DEFAULT now(),
--     updated_at timestamp with time zone DEFAULT now(),
--     middle_name text DEFAULT ''::text NOT NULL,
--     gender text DEFAULT ''::text NOT NULL,
--     phone_number text DEFAULT ''::text NOT NULL,
--     emergency_contact_phone text DEFAULT ''::text NOT NULL
-- );
-- ALTER TABLE public.passenger OWNER TO "Skybridge-Airways_Admin";

-- CREATE SEQUENCE public.passenger_id_seq
--     START WITH 1
--     INCREMENT BY 1
--     NO MINVALUE
--     NO MAXVALUE
--     CACHE 1;
-- ALTER SEQUENCE public.passenger_id_seq OWNER TO "Skybridge-Airways_Admin";
-- ALTER SEQUENCE public.passenger_id_seq OWNED BY public.passenger.id;

-- CREATE TABLE public.staff (
--     id bigint NOT NULL,
--     name text NOT NULL,
--     current_location text NOT NULL,
--     role text NOT NULL,
--     schedule jsonb,
--     created_at timestamp with time zone DEFAULT now()
-- );
-- ALTER TABLE public.staff OWNER TO "Skybridge-Airways_Admin";

-- CREATE SEQUENCE public.staff_id_seq
--     START WITH 1
--     INCREMENT BY 1
--     NO MINVALUE
--     NO MAXVALUE
--     CACHE 1;
-- ALTER SEQUENCE public.staff_id_seq OWNER TO "Skybridge-Airways_Admin";
-- ALTER SEQUENCE public.staff_id_seq OWNED BY public.staff.id;

-- ALTER TABLE ONLY public.account ALTER COLUMN id SET DEFAULT nextval('public.account_id_seq'::regclass);
-- ALTER TABLE ONLY public.booking ALTER COLUMN id SET DEFAULT nextval('public.booking_id_seq'::regclass);
-- ALTER TABLE ONLY public.passenger ALTER COLUMN id SET DEFAULT nextval('public.passenger_id_seq'::regclass);
-- ALTER TABLE ONLY public.staff ALTER COLUMN id SET DEFAULT nextval('public.staff_id_seq'::regclass);

-- ALTER TABLE ONLY public.account
--     ADD CONSTRAINT account_email_key UNIQUE (email);
-- ALTER TABLE ONLY public.account
--     ADD CONSTRAINT account_pkey PRIMARY KEY (id);

-- ALTER TABLE ONLY public.airplane
--     ADD CONSTRAINT airplane_pkey PRIMARY KEY (id);

-- ALTER TABLE ONLY public.airport_flight
--     ADD CONSTRAINT airport_flight_pkey PRIMARY KEY (airport_id, flight_id, relationship_type);

-- ALTER TABLE ONLY public.airport
--     ADD CONSTRAINT airport_pkey PRIMARY KEY (id);

-- ALTER TABLE ONLY public.booking_passenger
--     ADD CONSTRAINT booking_passenger_pkey PRIMARY KEY (booking_id, passenger_id);

-- ALTER TABLE ONLY public.booking
--     ADD CONSTRAINT booking_pkey PRIMARY KEY (id);

-- ALTER TABLE ONLY public.flight
--     ADD CONSTRAINT flight_pkey PRIMARY KEY (id);

-- ALTER TABLE ONLY public.flight_staff
--     ADD CONSTRAINT flight_staff_pkey PRIMARY KEY (flight_id, staff_id);

-- ALTER TABLE ONLY public.flyway_schema_history
--     ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);

-- ALTER TABLE ONLY public.passenger
--     ADD CONSTRAINT passenger_frequent_flyer_code_key UNIQUE (frequent_flyer_code);
-- ALTER TABLE ONLY public.passenger
--     ADD CONSTRAINT passenger_pkey PRIMARY KEY (id);

-- ALTER TABLE ONLY public.staff
--     ADD CONSTRAINT staff_pkey PRIMARY KEY (id);


-- CREATE INDEX flyway_schema_history_s_idx ON public.flyway_schema_history USING btree (success);
-- CREATE INDEX idx_bookings_flight ON public.booking USING btree (flight_id);
-- CREATE INDEX idx_flight_arrival ON public.flight USING btree (arrival_airport_id);
-- CREATE INDEX idx_flight_date ON public.flight USING btree (departure);
-- CREATE INDEX idx_flight_departure ON public.flight USING btree (departure_airport_id);
-- CREATE INDEX idx_passengers_email ON public.passenger USING btree (contact_email);

-- ALTER TABLE ONLY public.airplane
--     ADD CONSTRAINT airplane_location_fkey FOREIGN KEY (location) REFERENCES public.airport(id);

-- ALTER TABLE ONLY public.airport_flight
--     ADD CONSTRAINT airport_flight_airport_id_fkey FOREIGN KEY (airport_id) REFERENCES public.airport(id) ON DELETE CASCADE;

-- ALTER TABLE ONLY public.airport_flight
--     ADD CONSTRAINT airport_flight_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flight(id) ON DELETE CASCADE;

-- ALTER TABLE ONLY public.booking
--     ADD CONSTRAINT booking_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);
-- ALTER TABLE ONLY public.booking
--     ADD CONSTRAINT booking_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flight(id);

-- ALTER TABLE ONLY public.booking_passenger
--     ADD CONSTRAINT booking_passenger_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.booking(id);	
-- ALTER TABLE ONLY public.booking_passenger
--     ADD CONSTRAINT booking_passenger_passenger_id_fkey FOREIGN KEY (passenger_id) REFERENCES public.passenger(id);

-- ALTER TABLE ONLY public.flight
--     ADD CONSTRAINT flight_airplane_id_fkey FOREIGN KEY (airplane_id) REFERENCES public.airplane(id);
-- ALTER TABLE ONLY public.flight
--     ADD CONSTRAINT flight_arrival_airport_id_fkey FOREIGN KEY (arrival_airport_id) REFERENCES public.airport(id);
-- ALTER TABLE ONLY public.flight
--     ADD CONSTRAINT flight_departure_airport_id_fkey FOREIGN KEY (departure_airport_id) REFERENCES public.airport(id);

-- ALTER TABLE ONLY public.flight_staff
--     ADD CONSTRAINT flight_staff_flight_id_fkey FOREIGN KEY (flight_id) REFERENCES public.flight(id) ON DELETE CASCADE;
-- ALTER TABLE ONLY public.flight_staff
--     ADD CONSTRAINT flight_staff_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES public.staff(id) ON DELETE CASCADE;

-- ALTER TABLE ONLY public.passenger
--     ADD CONSTRAINT passenger_associated_to_fkey FOREIGN KEY (associated_to) REFERENCES public.account(id);

-- ALTER TABLE ONLY public.staff
--     ADD CONSTRAINT staff_current_location_fkey FOREIGN KEY (current_location) REFERENCES public.airport(id);

-- COMMIT;