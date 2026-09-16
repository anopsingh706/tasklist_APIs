-- ============================================================================
--  The exact query the API runs for GET /api/tasks.
--
--  Kept here so the result can be checked straight from the MySQL client,
--  without starting the Rust service:
--      mysql -u <user> -p < sql/03_api_query.sql
--
--  Expected: 12 rows (the parent tasks only - none of the 5 sub-tasks).
-- ============================================================================

USE tasklist;

SELECT
    t.id                              AS task_id,
    t.title                           AS title,
    t.description                     AS task,
    creator.name                      AS created_by,
    DATE_FORMAT(t.created_on, '%d-%m-%Y')   AS created_on,
    DATE_FORMAT(t.due_date, '%d-%m-%Y')     AS due_date,
    IFNULL(DATE_FORMAT(t.completed_on, '%d-%m-%Y'), '-') AS completed_on,
    t.status                          AS status,
    COALESCE(assignee.name, grp.name) AS assigned_to,
    CASE
        WHEN t.assigned_employee_id IS NOT NULL THEN 'employee'
        ELSE 'group'
    END                               AS assigned_to_type
FROM tasks AS t
INNER JOIN employees AS creator
        ON creator.id = t.created_by_id
LEFT JOIN employees AS assignee
        ON assignee.id = t.assigned_employee_id
LEFT JOIN employee_groups AS grp
        ON grp.id = t.assigned_group_id
WHERE t.parent_task_id = 0
ORDER BY t.id;
