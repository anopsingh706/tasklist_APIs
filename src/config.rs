//! Application configuration.
//!
//! Everything that changes between machines (database credentials, port,
//! pool size) is read from the environment, never from the source code.
//! In development the variables are loaded from a local `.env` file that is
//! git-ignored; in production they come from the real environment.

use std::env;

use anyhow::{Context, Result};

/// Values the application needs at start-up.
#[derive(Debug, Clone)]
pub struct Config {
    /// e.g. `mysql://user:password@localhost:3306/tasklist`
    pub database_url: String,
    /// Address the HTTP server binds to, e.g. `127.0.0.1:3000`.
    pub server_addr: String,
    /// Maximum number of pooled MySQL connections.
    pub db_max_connections: u32,
}

impl Config {
    /// Reads the configuration from the environment.
    ///
    /// `DATABASE_URL` is mandatory - the app refuses to start without it
    /// rather than falling back to a guessed set of credentials.
    pub fn from_env() -> Result<Self> {
        let database_url = env::var("DATABASE_URL").context(
            "DATABASE_URL is not set. Copy .env.example to .env and put your \
             MySQL connection string there.",
        )?;

        let server_addr =
            env::var("SERVER_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".to_string());

        let db_max_connections = match env::var("DB_MAX_CONNECTIONS") {
            Ok(value) => value
                .parse()
                .context("DB_MAX_CONNECTIONS must be a positive whole number")?,
            Err(_) => 5,
        };

        Ok(Self {
            database_url,
            server_addr,
            db_max_connections,
        })
    }
}
