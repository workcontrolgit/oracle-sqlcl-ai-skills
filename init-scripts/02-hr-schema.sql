WHENEVER SQLERROR EXIT SQL.SQLCODE;

ALTER SESSION SET CURRENT_SCHEMA = hr;

BEGIN
  FOR t IN (
    SELECT table_name
    FROM user_tables
    WHERE table_name IN (
      'JOB_HISTORY',
      'EMPLOYEES',
      'DEPARTMENTS',
      'LOCATIONS',
      'COUNTRIES',
      'REGIONS',
      'JOBS'
    )
  ) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
END;
/

CREATE TABLE regions (
  region_id NUMBER PRIMARY KEY,
  region_name VARCHAR2(25)
);

CREATE TABLE countries (
  country_id CHAR(2) PRIMARY KEY,
  country_name VARCHAR2(40),
  region_id NUMBER NOT NULL,
  CONSTRAINT fk_countries_region FOREIGN KEY (region_id) REFERENCES regions(region_id)
);

CREATE TABLE locations (
  location_id NUMBER(4) PRIMARY KEY,
  street_address VARCHAR2(40),
  postal_code VARCHAR2(12),
  city VARCHAR2(30) NOT NULL,
  state_province VARCHAR2(25),
  country_id CHAR(2) NOT NULL,
  CONSTRAINT fk_locations_country FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

CREATE TABLE departments (
  department_id NUMBER(4) PRIMARY KEY,
  department_name VARCHAR2(30) NOT NULL,
  manager_id NUMBER,
  location_id NUMBER(4),
  CONSTRAINT fk_departments_location FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

CREATE TABLE jobs (
  job_id VARCHAR2(10) PRIMARY KEY,
  job_title VARCHAR2(35) NOT NULL,
  min_salary NUMBER(6),
  max_salary NUMBER(6)
);

CREATE TABLE employees (
  employee_id NUMBER(6) PRIMARY KEY,
  first_name VARCHAR2(20),
  last_name VARCHAR2(25) NOT NULL,
  email VARCHAR2(25) NOT NULL UNIQUE,
  phone_number VARCHAR2(20),
  hire_date DATE NOT NULL,
  job_id VARCHAR2(10) NOT NULL,
  salary NUMBER(8,2),
  commission_pct NUMBER(2,2),
  manager_id NUMBER(6),
  department_id NUMBER(4),
  CONSTRAINT fk_employees_job FOREIGN KEY (job_id) REFERENCES jobs(job_id),
  CONSTRAINT fk_employees_dept FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT fk_employees_mgr FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

CREATE TABLE job_history (
  employee_id NUMBER(6) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  job_id VARCHAR2(10) NOT NULL,
  department_id NUMBER(4),
  CONSTRAINT pk_job_history PRIMARY KEY (employee_id, start_date),
  CONSTRAINT fk_jobhist_employee FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
  CONSTRAINT fk_jobhist_job FOREIGN KEY (job_id) REFERENCES jobs(job_id),
  CONSTRAINT fk_jobhist_dept FOREIGN KEY (department_id) REFERENCES departments(department_id),
  CONSTRAINT ck_job_history_dates CHECK (end_date > start_date)
);

INSERT INTO regions (region_id, region_name) VALUES (1, 'Europe');
INSERT INTO regions (region_id, region_name) VALUES (2, 'Americas');
INSERT INTO regions (region_id, region_name) VALUES (3, 'Asia');
INSERT INTO regions (region_id, region_name) VALUES (4, 'Middle East and Africa');

INSERT INTO countries (country_id, country_name, region_id) VALUES ('US', 'United States of America', 2);
INSERT INTO countries (country_id, country_name, region_id) VALUES ('UK', 'United Kingdom', 1);
INSERT INTO countries (country_id, country_name, region_id) VALUES ('JP', 'Japan', 3);
INSERT INTO countries (country_id, country_name, region_id) VALUES ('DE', 'Germany', 1);

INSERT INTO locations (location_id, street_address, postal_code, city, state_province, country_id)
VALUES (1000, '1297 Via Cola di Rie', '00989', 'Roma', NULL, 'DE');
INSERT INTO locations (location_id, street_address, postal_code, city, state_province, country_id)
VALUES (1100, '93091 Calle della Testa', '10934', 'Venice', NULL, 'UK');
INSERT INTO locations (location_id, street_address, postal_code, city, state_province, country_id)
VALUES (1200, '2017 Shinjuku-ku', '1689', 'Tokyo', 'Tokyo Prefecture', 'JP');
INSERT INTO locations (location_id, street_address, postal_code, city, state_province, country_id)
VALUES (1700, '2004 Charade Rd', '98199', 'Seattle', 'Washington', 'US');

INSERT INTO departments (department_id, department_name, manager_id, location_id)
VALUES (10, 'Administration', NULL, 1700);
INSERT INTO departments (department_id, department_name, manager_id, location_id)
VALUES (20, 'Marketing', NULL, 1700);
INSERT INTO departments (department_id, department_name, manager_id, location_id)
VALUES (30, 'Purchasing', NULL, 1700);
INSERT INTO departments (department_id, department_name, manager_id, location_id)
VALUES (60, 'IT', NULL, 1200);

INSERT INTO jobs (job_id, job_title, min_salary, max_salary)
VALUES ('AD_PRES', 'President', 20080, 40000);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary)
VALUES ('AD_VP', 'Administration Vice President', 15000, 30000);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary)
VALUES ('IT_PROG', 'Programmer', 4000, 10000);
INSERT INTO jobs (job_id, job_title, min_salary, max_salary)
VALUES ('MK_MAN', 'Marketing Manager', 9000, 15000);

INSERT INTO employees (
  employee_id, first_name, last_name, email, phone_number, hire_date,
  job_id, salary, commission_pct, manager_id, department_id
) VALUES (
  100, 'Steven', 'King', 'SKING', '515.123.4567', DATE '2003-06-17',
  'AD_PRES', 24000, NULL, NULL, 10
);

INSERT INTO employees (
  employee_id, first_name, last_name, email, phone_number, hire_date,
  job_id, salary, commission_pct, manager_id, department_id
) VALUES (
  101, 'Neena', 'Kochhar', 'NKOCHHAR', '515.123.4568', DATE '2005-09-21',
  'AD_VP', 17000, NULL, 100, 10
);

INSERT INTO employees (
  employee_id, first_name, last_name, email, phone_number, hire_date,
  job_id, salary, commission_pct, manager_id, department_id
) VALUES (
  102, 'Lex', 'De Haan', 'LDEHAAN', '515.123.4569', DATE '2001-01-13',
  'AD_VP', 17000, NULL, 100, 10
);

INSERT INTO employees (
  employee_id, first_name, last_name, email, phone_number, hire_date,
  job_id, salary, commission_pct, manager_id, department_id
) VALUES (
  103, 'Alexander', 'Hunold', 'AHUNOLD', '590.423.4567', DATE '2006-01-03',
  'IT_PROG', 9000, NULL, 102, 60
);

INSERT INTO employees (
  employee_id, first_name, last_name, email, phone_number, hire_date,
  job_id, salary, commission_pct, manager_id, department_id
) VALUES (
  104, 'Bruce', 'Ernst', 'BERNST', '590.423.4568', DATE '2007-05-21',
  'IT_PROG', 6000, NULL, 103, 60
);

UPDATE departments SET manager_id = 100 WHERE department_id = 10;
UPDATE departments SET manager_id = 101 WHERE department_id = 20;
UPDATE departments SET manager_id = 102 WHERE department_id = 60;

INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id)
VALUES (103, DATE '2006-01-03', DATE '2008-12-31', 'IT_PROG', 60);

COMMIT;
