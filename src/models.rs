//! Database rows and the JSON shapes returned by the API.
//!
//! `TaskRow` mirrors the columns coming back from MySQL; `TaskResponse` is the
//! client-facing shape. Keeping them separate means the JSON contract does not
//! silently change every time a column is renamed.

use chrono::{NaiveDate, NaiveDateTime};
use serde::Serialize;
use sqlx::FromRow;

/// Dates are presented the way the requirement shows them: `16-09-2026`.
const DISPLAY_DATE_FORMAT: &str = "%d-%m-%Y";

/// One row of the "list parent tasks" query.
#[derive(Debug, FromRow)]
pub struct TaskRow {
    pub id: u64,
    pub title: String,
    pub description: Option<String>,
    /// Name of the employee who created the task (resolved by a JOIN).
    pub created_by: String,
    pub created_on: NaiveDateTime,
    pub due_date: Option<NaiveDate>,
    pub completed_on: Option<NaiveDateTime>,
    pub status: String,
    /// Employee name or group name, whichever the task is assigned to.
    pub assigned_to: Option<String>,
    /// `"employee"` or `"group"` - tells the client which one the name is.
    pub assigned_to_type: String,
}

/// A single task as returned by `GET /api/tasks`.
#[derive(Debug, Serialize)]
pub struct TaskResponse {
    pub task_id: u64,
    pub title: String,
    /// The task detail / description ("Task" in the requirement).
    pub task: Option<String>,
    pub created_by: String,
    pub created_on: String,
    /// `null` when the task has no deadline.
    pub due_date: Option<String>,
    /// `null` while the task is not completed - the UI renders that as "-".
    pub completed_on: Option<String>,
    pub status: String,
    pub assigned_to: String,
    pub assigned_to_type: String,
}

impl From<TaskRow> for TaskResponse {
    fn from(row: TaskRow) -> Self {
        Self {
            task_id: row.id,
            title: row.title,
            task: row.description,
            created_by: row.created_by,
            created_on: row.created_on.format(DISPLAY_DATE_FORMAT).to_string(),
            due_date: row.due_date.map(|d| d.format(DISPLAY_DATE_FORMAT).to_string()),
            completed_on: row
                .completed_on
                .map(|d| d.format(DISPLAY_DATE_FORMAT).to_string()),
            status: row.status,
            // The database CHECK constraint guarantees every task has exactly
            // one assignee, so this fallback should never be hit in practice.
            assigned_to: row.assigned_to.unwrap_or_else(|| "Unassigned".to_string()),
            assigned_to_type: row.assigned_to_type,
        }
    }
}

/// Envelope for the task list, so the client gets a stable object to read
/// instead of a bare JSON array.
#[derive(Debug, Serialize)]
pub struct TaskListResponse {
    pub success: bool,
    pub count: usize,
    pub data: Vec<TaskResponse>,
}

impl TaskListResponse {
    pub fn new(tasks: Vec<TaskResponse>) -> Self {
        Self {
            success: true,
            count: tasks.len(),
            data: tasks,
        }
    }
}
