@echo off
rem Opens a SQL shell into the local analyzer database (PostgreSQL 17, port
rem 5433, trust auth on loopback). Local testing only - the production database
rem on the server has its own password and lives inside Docker.
"C:\Users\USER\pg17\pgsql\bin\psql.exe" -h 127.0.0.1 -p 5433 -U postgres -d analyzer
