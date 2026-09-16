//! Task List API - Rust (Axum) + MySQL (SQLx).
//!
//! Start-up sequence:
//!   .env -> Config -> MySQL pool -> router -> listen.

mod config;
mod db;
mod error;
mod handlers;
mod models;
mod repository;

use anyhow::{Context, Result};
use axum::{routing::get, Router};
use sqlx::MySqlPool;
use tokio::net::TcpListener;
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() -> Result<()> {
    // Load .env if present; real environment variables always win.
    dotenvy::dotenv().ok();
    init_tracing();

    let config = config::Config::from_env()?;

    let pool = db::create_pool(&config.database_url, config.db_max_connections).await?;
    tracing::info!("connected to MySQL");

    let app = build_router(pool);

    let listener = TcpListener::bind(&config.server_addr)
        .await
        .with_context(|| format!("could not bind to {}", config.server_addr))?;

    tracing::info!("listening on http://{}", config.server_addr);
    tracing::info!("task list endpoint: http://{}/api/tasks", config.server_addr);

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .context("server error")?;

    Ok(())
}

/// Routes. The pool is shared state, cloned cheaply into each handler.
fn build_router(pool: MySqlPool) -> Router {
    Router::new()
        .route("/health", get(handlers::health))
        .route("/api/tasks", get(handlers::list_tasks))
        .layer(TraceLayer::new_for_http())
        .with_state(pool)
}

/// `RUST_LOG` controls verbosity; default shows this crate at info level.
fn init_tracing() {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("tasklist_api=info,tower_http=info,axum=info"));

    tracing_subscriber::registry()
        .with(filter)
        .with(tracing_subscriber::fmt::layer())
        .init();
}

/// Lets in-flight requests finish when Ctrl+C is pressed.
async fn shutdown_signal() {
    if let Err(err) = tokio::signal::ctrl_c().await {
        tracing::error!(error = %err, "failed to listen for shutdown signal");
        return;
    }
    tracing::info!("shutdown signal received");
}
