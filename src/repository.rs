//! All SQL lives here, so the handlers stay free of query strings and the
//! queries can be read (and tuned) in one place.

use sqlx::MySqlPool;

use crate::models::TaskRow;

/// A task whose `parent_task_id` is 0 is a top-level ("parent") task.
/// Sub-tasks carry the id of their parent instead.
pub const ROOT_PARENT_TASK_ID: u64 = 0;

/// Lists parent tasks with the creator and assignee names already resolved.
///
/// * `creator`  - always present, so an INNER JOIN.
/// * `assignee` / `grp` - only one of the two is set on any given row, so both
///   are LEFT JOINs and `COALESCE` picks whichever name exists.
const LIST_PARENT_TASKS_SQL: &str = r#"
SELECT
    t.id                              AS id,
    t.title                           AS title,
    t.description                     AS description,
    creator.name                      AS created_by,
    t.created_on                      AS created_on,
    t.due_date                        AS due_date,
    t.completed_on                    AS completed_on,
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
WHERE t.parent_task_id = ?
ORDER BY t.id
"#;

/// Fetches every parent task (`parent_task_id = 0`). Sub-tasks are excluded.
pub async fn list_parent_tasks(pool: &MySqlPool) -> Result<Vec<TaskRow>, sqlx::Error> {
    sqlx::query_as::<_, TaskRow>(LIST_PARENT_TASKS_SQL)
        .bind(ROOT_PARENT_TASK_ID)
        .fetch_all(pool)
        .await
}

/// Cheap round-trip used by the health check.
pub async fn ping(pool: &MySqlPool) -> Result<(), sqlx::Error> {
    sqlx::query("SELECT 1").execute(pool).await.map(|_| ())
}
