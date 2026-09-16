-- ============================================================================
--  Task List API - schema
--  MySQL 8.0+ (uses CHECK constraints, which are enforced from 8.0.16)
--
--  Run with:  mysql -u <user> -p < sql/01_schema.sql
-- ============================================================================

CREATE DATABASE IF NOT EXISTS tasklist
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE tasklist;

-- Dropped child-first so the script can be re-run from scratch.
DROP TABLE IF EXISTS tasks;
DROP TABLE IF EXISTS group_members;
DROP TABLE IF EXISTS employee_groups;
DROP TABLE IF EXISTS employees;

-- ---------------------------------------------------------------------------
--  employees
-- ---------------------------------------------------------------------------
CREATE TABLE employees (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(120)    NOT NULL,
    email       VARCHAR(190)    NOT NULL,
    designation VARCHAR(120)         NULL,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_employees_email (email)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
--  employee_groups  ("Sales Team", "Support Team", ...)
--
--  Named `employee_groups` rather than `groups` because GROUPS is a reserved
--  word in MySQL 8.0 and would need back-ticking in every single query.
-- ---------------------------------------------------------------------------
CREATE TABLE employee_groups (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(120)    NOT NULL,
    description VARCHAR(255)         NULL,
    created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id),
    UNIQUE KEY uq_employee_groups_name (name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
--  group_members  -  many-to-many between employees and groups.
--
--  Not needed by the "view all tasks" endpoint, but a group is meaningless
--  without members and it is what lets a future endpoint answer
--  "which people actually have to do this group task?".
-- ---------------------------------------------------------------------------
CREATE TABLE group_members (
    group_id    BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED NOT NULL,
    joined_at   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (group_id, employee_id),
    KEY idx_group_members_employee (employee_id),

    CONSTRAINT fk_group_members_group
        FOREIGN KEY (group_id)    REFERENCES employee_groups (id) ON DELETE CASCADE,
    CONSTRAINT fk_group_members_employee
        FOREIGN KEY (employee_id) REFERENCES employees (id)       ON DELETE CASCADE
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------------
--  tasks
--
--  Assignment rule: a task is assigned to EXACTLY ONE of
--    - an employee (assigned_employee_id), or
--    - a group    (assigned_group_id)
--  The CHECK constraint below makes the database enforce that, so bad data
--  cannot be written even by something other than this API.
--
--  parent_task_id: 0 means "this is a top-level / parent task", as required by
--  the spec. 0 is a sentinel rather than NULL, so it cannot carry a real
--  foreign key - see README ("Why parent_task_id = 0 and not NULL").
-- ---------------------------------------------------------------------------
CREATE TABLE tasks (
    id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    title                VARCHAR(255)    NOT NULL,
    description          TEXT                 NULL,

    created_by_id        BIGINT UNSIGNED NOT NULL,
    created_on           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date             DATE                 NULL,
    completed_on         DATETIME             NULL,

    status               ENUM('Pending', 'In Progress', 'Completed', 'Cancelled')
                                         NOT NULL DEFAULT 'Pending',

    parent_task_id       BIGINT UNSIGNED NOT NULL DEFAULT 0,

    assigned_employee_id BIGINT UNSIGNED      NULL,
    assigned_group_id    BIGINT UNSIGNED      NULL,

    updated_at           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                             ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (id),

    -- The list endpoint filters on parent_task_id and orders by due_date.
    KEY idx_tasks_parent        (parent_task_id),
    KEY idx_tasks_status        (status),
    KEY idx_tasks_due_date      (due_date),
    KEY idx_tasks_assigned_emp  (assigned_employee_id),
    KEY idx_tasks_assigned_grp  (assigned_group_id),

    CONSTRAINT fk_tasks_created_by
        FOREIGN KEY (created_by_id)        REFERENCES employees (id),
    CONSTRAINT fk_tasks_assigned_employee
        FOREIGN KEY (assigned_employee_id) REFERENCES employees (id),
    CONSTRAINT fk_tasks_assigned_group
        FOREIGN KEY (assigned_group_id)    REFERENCES employee_groups (id),

    -- Assigned to an employee OR a group - never both, never neither.
    CONSTRAINT chk_tasks_single_assignee CHECK (
        (assigned_employee_id IS NOT NULL AND assigned_group_id IS NULL)
        OR
        (assigned_employee_id IS NULL AND assigned_group_id IS NOT NULL)
    ),

    -- A completed task must have a completion date, and vice versa.
    CONSTRAINT chk_tasks_completed_on CHECK (
        (status = 'Completed' AND completed_on IS NOT NULL)
        OR
        (status <> 'Completed' AND completed_on IS NULL)
    )
) ENGINE = InnoDB;
