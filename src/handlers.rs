//! HTTP handlers. These only translate between HTTP and the repository -
//! no SQL, no business rules.

use axum::{extract::State, Json};
use serde_json::{json, Value};
use sqlx::MySqlPool;

use crate::{
    error::AppError,
    models::{TaskListResponse, TaskResponse},
    repository,
};

/// `GET /api/tasks`
///
/// Returns all **parent** tasks (`parent_task_id = 0`) with the creator name
/// and the assignee name (employee or group) already resolved.
pub async fn list_tasks(
    State(pool): State<MySqlPool>,
) -> Result<Json<TaskListResponse>, AppError> {
    let rows = repository::list_parent_tasks(&pool).await?;

    tracing::debug!(count = rows.len(), "fetched parent tasks");

    let tasks: Vec<TaskResponse> = rows.into_iter().map(TaskResponse::from).collect();

    Ok(Json(TaskListResponse::new(tasks)))
}

/// `GET /health` - confirms the service is up and the database answers.
pub async fn health(State(pool): State<MySqlPool>) -> Result<Json<Value>, AppError> {
    repository::ping(&pool).await?;

    Ok(Json(json!({
        "status": "ok",
        "database": "reachable",
    })))
}
