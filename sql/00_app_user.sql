-- ============================================================================
--  Optional: a dedicated MySQL user for the API.
--
--  The API should not run as root. This user can only read/write the tasklist
--  database. Replace the password before running:
--
--      mysql -u root -p < sql/00_app_user.sql
--
--  Then use it in .env:
--      DATABASE_URL=mysql://tasklist_user:<the password>@localhost:3306/tasklist
-- ============================================================================

CREATE USER IF NOT EXISTS 'tasklist_user'@'localhost'
    IDENTIFIED BY 'ChangeThisPassword!123';

GRANT SELECT, INSERT, UPDATE, DELETE
    ON tasklist.*
    TO 'tasklist_user'@'localhost';

FLUSH PRIVILEGES;
