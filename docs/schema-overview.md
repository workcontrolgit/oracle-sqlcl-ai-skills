# HR Schema Overview

The workspace creates a lightweight version of the Oracle HR sample schema.

## Tables

- `regions`: Geographic regions.
- `countries`: Countries mapped to regions.
- `locations`: Physical office locations mapped to countries.
- `departments`: Company departments mapped to locations and managers.
- `jobs`: Role catalog with salary bands.
- `employees`: Employee records with manager hierarchy.
- `job_history`: Historical job assignments.

## Relationship Highlights

- `countries.region_id -> regions.region_id`
- `locations.country_id -> countries.country_id`
- `departments.location_id -> locations.location_id`
- `employees.department_id -> departments.department_id`
- `employees.job_id -> jobs.job_id`
- `employees.manager_id -> employees.employee_id`
- `job_history.employee_id -> employees.employee_id`
