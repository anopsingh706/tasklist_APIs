//! MySQL connection pool.

use std::time::Duration;

use anyhow::{Context, Result};
use sqlx::mysql::{MySqlPool, MySqlPoolOptions};

/// Creates the connection pool and verifies the database is actually reachable.
///
/// A pool is created once at start-up and shared by every request handler
/// (it is cheap to clone - internally it is an `Arc`), so requests reuse
/// existing connections instead of opening a new one each time.
pub async fn create_pool(database_url: &str, max_connections: u32) -> Result<MySqlPool> {
    let pool = MySqlPoolOptions::new()
        .max_connections(max_connections)
        .acquire_timeout(Duration::from_secs(5))
        .connect(database_url)
        .await
        .context("could not connect to MySQL - check DATABASE_URL and that the server is running")?;

    // Fail fast at boot instead of returning 500s on the first request.
    sqlx::query("SELECT 1")
        .execute(&pool)
        .await
        .context("connected to MySQL but the test query failed")?;

    Ok(pool)
}
