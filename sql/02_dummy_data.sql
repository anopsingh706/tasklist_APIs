-- ============================================================================
--  Task List API - dummy data for testing
--
--  Run AFTER sql/01_schema.sql:
--      mysql -u <user> -p < sql/02_dummy_data.sql
--
--  Contents:
--    6 employees, 3 groups, 17 tasks
--      - 12 parent tasks   (parent_task_id = 0)  <- what GET /api/tasks returns
--      -  5 sub-tasks      (parent_task_id > 0)  <- must NOT appear in the list
--      - tasks assigned to employees and tasks assigned to groups
--      - Pending / In Progress / Completed / Cancelled tasks
--      - one overdue task and one task with no due date
-- ============================================================================

USE tasklist;

-- Wipe existing rows so this file can be re-run. Order matters (FKs).
DELETE FROM tasks;
DELETE FROM group_members;
DELETE FROM employee_groups;
DELETE FROM employees;

ALTER TABLE employees       AUTO_INCREMENT = 1;
ALTER TABLE employee_groups AUTO_INCREMENT = 1;
ALTER TABLE tasks           AUTO_INCREMENT = 101;  -- task ids start at 101

-- ---------------------------------------------------------------------------
--  Employees
-- ---------------------------------------------------------------------------
INSERT INTO employees (id, name, email, designation) VALUES
    (1, 'Amit Sharma',   'amit.sharma@example.com',   'Sales Manager'),
    (2, 'Rahul Kumar',   'rahul.kumar@example.com',   'Sales Executive'),
    (3, 'Priya Nair',    'priya.nair@example.com',    'Support Lead'),
    (4, 'Sandeep Verma', 'sandeep.verma@example.com', 'Accounts Executive'),
    (5, 'Neha Gupta',    'neha.gupta@example.com',    'Support Executive'),
    (6, 'Vikram Singh',  'vikram.singh@example.com',  'Field Engineer');

-- ---------------------------------------------------------------------------
--  Groups
-- ---------------------------------------------------------------------------
INSERT INTO employee_groups (id, name, description) VALUES
    (1, 'Sales Team',    'Handles leads, quotations and customer follow-ups'),
    (2, 'Support Team',  'Handles customer complaints and service requests'),
    (3, 'Accounts Team', 'Handles invoicing, payments and reconciliation');

-- ---------------------------------------------------------------------------
--  Group members
-- ---------------------------------------------------------------------------
INSERT INTO group_members (group_id, employee_id) VALUES
    (1, 1),   -- Sales Team    : Amit Sharma
    (1, 2),   --               : Rahul Kumar
    (2, 3),   -- Support Team  : Priya Nair
    (2, 5),   --               : Neha Gupta
    (2, 6),   --               : Vikram Singh
    (3, 4);   -- Accounts Team : Sandeep Verma

-- ---------------------------------------------------------------------------
--  Tasks - parent tasks (parent_task_id = 0)
--
--  Column order:
--    id, title, description, created_by_id, created_on, due_date,
--    completed_on, status, parent_task_id, assigned_employee_id,
--    assigned_group_id
-- ---------------------------------------------------------------------------
INSERT INTO tasks
    (id, title, description, created_by_id, created_on, due_date,
     completed_on, status, parent_task_id, assigned_employee_id, assigned_group_id)
VALUES
    -- 1. assigned to an employee, pending
    (101, 'Follow up with customer',
          'Call ABC Industries regarding pending payment',
          1, '2026-09-14 09:30:00', '2026-09-18',
          NULL, 'Pending', 0, 2, NULL),

    -- 2. assigned to a group, in progress
    (102, 'Prepare Q3 sales report',
          'Consolidate region-wise numbers for the quarterly review meeting',
          1, '2026-09-10 11:00:00', '2026-09-20',
          NULL, 'In Progress', 0, NULL, 1),

    -- 3. assigned to an employee, completed
    (103, 'Send quotation to XYZ Pvt Ltd',
          'Share the revised quotation for the annual maintenance contract',
          1, '2026-09-05 10:15:00', '2026-09-08',
          '2026-09-07 16:40:00', 'Completed', 0, 2, NULL),

    -- 4. assigned to a group, pending
    (104, 'Resolve pending support tickets',
          'Clear all tickets older than 7 days from the helpdesk queue',
          3, '2026-09-12 14:00:00', '2026-09-19',
          NULL, 'Pending', 0, NULL, 2),

    -- 5. assigned to an employee, overdue (due date in the past, still pending)
    (105, 'Reconcile August vendor invoices',
          'Match vendor invoices against purchase orders for August 2026',
          1, '2026-09-01 09:00:00', '2026-09-10',
          NULL, 'Pending', 0, 4, NULL),

    -- 6. assigned to a group, completed
    (106, 'Month end invoicing',
          'Generate and email all customer invoices for August 2026',
          1, '2026-08-28 09:00:00', '2026-09-03',
          '2026-09-02 18:20:00', 'Completed', 0, NULL, 3),

    -- 7. assigned to an employee, in progress
    (107, 'Onboard new dealer in Pune',
          'Complete documentation and credit check for the new Pune dealer',
          1, '2026-09-11 10:00:00', '2026-09-25',
          NULL, 'In Progress', 0, 1, NULL),

    -- 8. assigned to an employee, cancelled
    (108, 'Arrange product demo at trade fair',
          'Customer cancelled participation, demo no longer required',
          3, '2026-09-02 12:30:00', '2026-09-15',
          NULL, 'Cancelled', 0, 6, NULL),

    -- 9. assigned to a group, pending, NO due date
    (109, 'Update customer contact database',
          'Clean up duplicate contacts and add missing phone numbers',
          1, '2026-09-13 15:45:00', NULL,
          NULL, 'Pending', 0, NULL, 1),

    -- 10. assigned to an employee, completed
    (110, 'Service visit - Sunrise Textiles',
          'On-site inspection of the machine reported faulty on 04-09-2026',
          3, '2026-09-04 08:30:00', '2026-09-06',
          '2026-09-06 13:10:00', 'Completed', 0, 6, NULL),

    -- 11. assigned to a group, in progress
    (111, 'Prepare festive season offer sheet',
          'Draft discount slabs for the October festive campaign',
          1, '2026-09-15 11:20:00', '2026-09-30',
          NULL, 'In Progress', 0, NULL, 1),

    -- 12. assigned to an employee, pending
    (112, 'Train new support executive',
          'Walk Neha through the ticketing tool and escalation matrix',
          3, '2026-09-15 16:00:00', '2026-09-22',
          NULL, 'Pending', 0, 5, NULL);

-- ---------------------------------------------------------------------------
--  Tasks - sub-tasks (parent_task_id <> 0)
--
--  These must NOT show up in GET /api/tasks.
-- ---------------------------------------------------------------------------
INSERT INTO tasks
    (id, title, description, created_by_id, created_on, due_date,
     completed_on, status, parent_task_id, assigned_employee_id, assigned_group_id)
VALUES
    -- sub-tasks of 102 (Prepare Q3 sales report)
    (201, 'Collect North region numbers',
          'Get the region-wise sales figures from the North branch',
          1, '2026-09-10 11:30:00', '2026-09-16',
          '2026-09-15 12:00:00', 'Completed', 102, 2, NULL),

    (202, 'Collect South region numbers',
          'Get the region-wise sales figures from the South branch',
          1, '2026-09-10 11:35:00', '2026-09-16',
          NULL, 'In Progress', 102, NULL, 1),

    -- sub-tasks of 104 (Resolve pending support tickets)
    (203, 'Call back escalated customers',
          'Personally call the 5 customers who escalated last week',
          3, '2026-09-12 14:15:00', '2026-09-17',
          NULL, 'Pending', 104, 5, NULL),

    (204, 'Close duplicate tickets',
          'Merge and close tickets raised twice for the same issue',
          3, '2026-09-12 14:20:00', '2026-09-17',
          NULL, 'Pending', 104, NULL, 2),

    -- sub-task of 105 (Reconcile August vendor invoices)
    (205, 'Request missing invoices from vendors',
          'Email the 3 vendors who have not shared August invoices',
          4, '2026-09-02 10:00:00', '2026-09-08',
          '2026-09-08 11:45:00', 'Completed', 105, 4, NULL);

-- ---------------------------------------------------------------------------
--  Quick sanity check (should print 12 parent tasks and 5 sub-tasks)
-- ---------------------------------------------------------------------------
SELECT
    CASE WHEN parent_task_id = 0 THEN 'parent tasks' ELSE 'sub-tasks' END AS task_type,
    COUNT(*) AS total
FROM tasks
GROUP BY task_type;
