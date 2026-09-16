//! Application error type.
//!
//! Handlers return `Result<_, AppError>`; `AppError` knows how to turn itself
//! into an HTTP response, so a database failure becomes a clean JSON 500
//! instead of a panic. The internal error text is logged, never sent to the
//! client.

use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::Database(err) => {
                tracing::error!(error = %err, "database query failed");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Internal server error while reading tasks",
                )
            }
        };

        let body = Json(json!({
            "success": false,
            "error": message,
        }));

        (status, body).into_response()
    }
}
