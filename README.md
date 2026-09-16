# Task List API — Rust (Axum) + MySQL (SQLx)

A small task-management API. It exposes one main endpoint that lists all
**parent** tasks (`parent_task_id = 0`) with the creator's name and the
assignee's name — where the assignee is either an employee or a group.

---

## 1. Requirements

| Tool  | Version                                                  |
| ----- | -------------------------------------------------------- |
| Rust  | 1.75 or newer (`rustup` — <https://rustup.rs>)            |
| MySQL | 8.0.16 or newer (the schema uses `CHECK` constraints)     |

Rust on Windows also needs a linker. Either works:

- **MSVC toolchain** (rustup's default) — install the *Visual Studio Build
  Tools* with the "Desktop development with C++" workload, which includes the
  Windows SDK. The MSVC compiler alone is not enough; without the SDK, linking
  fails.
- **GNU toolchain** — `rustup default stable-x86_64-pc-windows-gnu` plus a
  MinGW-w64 on `PATH` (e.g. [w64devkit](https://github.com/skeeto/w64devkit),
  portable, no admin rights). This is what this project was built and verified
  with on the development machine. The `dlltool.exe` that ships inside the Rust
  toolchain is not sufficient on its own — it cannot find its assembler — so a
  real MinGW `bin` directory has to be on `PATH`.

On Linux/macOS the system C toolchain already covers this; nothing extra is
needed.

---

## 2. Setup

### 2.1 Create the database, tables and dummy data

```bash
# from the project root
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_dummy_data.sql
```

`01_schema.sql` creates the `tasklist` database and all four tables.
`02_dummy_data.sql` inserts 6 employees, 3 groups and 17 tasks
(12 parent tasks + 5 sub-tasks) and prints a count so you can confirm it loaded.

Optionally create a non-root user for the API (edit the password inside first):

```bash
mysql -u root -p < sql/00_app_user.sql
```

### 2.2 Configure the connection

Credentials are **not** in the source code. Copy the sample env file and edit it:

```bash
cp .env.example .env      # Windows: copy .env.example .env
```

```dotenv
DATABASE_URL=mysql://tasklist_user:your_password@localhost:3306/tasklist
SERVER_ADDR=127.0.0.1:3000
DB_MAX_CONNECTIONS=5
```

`.env` is git-ignored. The app reads real environment variables too, and those
take priority — so in production you set `DATABASE_URL` in the environment and
ship no `.env` at all.

### 2.3 Run

```bash
cargo run            # development
cargo run --release  # optimised
```

```
INFO tasklist_api: connected to MySQL
INFO tasklist_api: listening on http://127.0.0.1:3000
INFO tasklist_api: task list endpoint: http://127.0.0.1:3000/api/tasks
```

---

## 3. API

| Method | Endpoint     | Description                                    |
| ------ | ------------ | ---------------------------------------------- |
| GET    | `/api/tasks` | All parent tasks (`parent_task_id = 0`)        |
| GET    | `/health`    | Service + database reachability check          |

### Try it

```bash
curl http://127.0.0.1:3000/api/tasks
```

### Sample response (trimmed to 3 of the 12 tasks)

```json
{
  "success": true,
  "count": 12,
  "data": [
    {
      "task_id": 101,
      "title": "Follow up with customer",
      "task": "Call ABC Industries regarding pending payment",
      "created_by": "Amit Sharma",
      "created_on": "14-09-2026",
      "due_date": "18-09-2026",
      "completed_on": null,
      "status": "Pending",
      "assigned_to": "Rahul Kumar",
      "assigned_to_type": "employee"
    },
    {
      "task_id": 102,
      "title": "Prepare Q3 sales report",
      "task": "Consolidate region-wise numbers for the quarterly review meeting",
      "created_by": "Amit Sharma",
      "created_on": "10-09-2026",
      "due_date": "20-09-2026",
      "completed_on": null,
      "status": "In Progress",
      "assigned_to": "Sales Team",
      "assigned_to_type": "group"
    },
    {
      "task_id": 103,
      "title": "Send quotation to XYZ Pvt Ltd",
      "task": "Share the revised quotation for the annual maintenance contract",
      "created_by": "Amit Sharma",
      "created_on": "05-09-2026",
      "due_date": "08-09-2026",
      "completed_on": "07-09-2026",
      "status": "Completed",
      "assigned_to": "Rahul Kumar",
      "assigned_to_type": "employee"
    }
  ]
}
```

Notes on the shape:

- Dates are formatted `DD-MM-YYYY`, as in the requirement.
- `completed_on` is `null` (not `"-"`) when the task is not finished. `null` is
  the honest JSON value for "no date"; rendering it as `-` is the client's job.
- `assigned_to_type` tells the client whether `assigned_to` is a person or a
  team, so the UI can show the right icon without a second lookup.
- Sub-tasks (101's siblings 201–205) never appear here — see §4.4.

`/health` returns:

```json
{ "status": "ok", "database": "reachable" }
```

---

## 4. Design decisions

### 4.1 Why the tables are shaped this way

**Four tables: `employees`, `employee_groups`, `group_members`, `tasks`.**

- `employees` and `employee_groups` are the two kinds of thing a task can be
  assigned to. Each has its own table because they are genuinely different
  entities — a group has members, an employee has an email and a designation.
- `group_members` is the many-to-many link between them. The list endpoint does
  not need it, but a group is meaningless without members, and it is what lets a
  later endpoint answer "which people actually have to do this group task?".
- `tasks` holds the task itself plus the two nullable assignment columns.
- The group table is named `employee_groups` rather than `groups` because
  `GROUPS` is a reserved word in MySQL 8.0 and would need back-ticking in every
  query.
- Every relationship is a real `FOREIGN KEY`, so you cannot have a task created
  by a non-existent employee, and deleting a referenced employee is blocked.
- Indexes exist on the columns the endpoint actually uses: `parent_task_id`
  (the filter), `due_date`, `status`, and both assignment columns.
- `ENUM` for `status` keeps the values constrained at the database level.
  A lookup table would be the choice if statuses needed to be editable at
  runtime; here the four states are fixed by the workflow.

**Why `parent_task_id = 0` and not `NULL`.** The requirement specifies 0 for a
top-level task, so that is what the schema does. The trade-off is that `0` is a
sentinel and cannot carry a foreign key (there is no employee/task with id 0),
so the parent link is not FK-enforced. `NULL` with a self-referencing
`FOREIGN KEY (parent_task_id) REFERENCES tasks(id)` would give real referential
integrity. Both work; the spec's `0` convention was followed and `AUTO_INCREMENT`
starts at 101, so no real task can ever collide with the sentinel.

### 4.2 How employee vs group assignment is handled

`tasks` has two nullable columns:

```sql
assigned_employee_id BIGINT UNSIGNED NULL  -- FK -> employees(id)
assigned_group_id    BIGINT UNSIGNED NULL  -- FK -> employee_groups(id)
```

Exactly one is filled, enforced by the database, not just by application code:

```sql
CONSTRAINT chk_tasks_single_assignee CHECK (
    (assigned_employee_id IS NOT NULL AND assigned_group_id IS NULL)
    OR
    (assigned_employee_id IS NULL AND assigned_group_id IS NOT NULL)
)
```

So a task assigned to both, or to nobody, is rejected by MySQL — even if it is
inserted by something other than this API.

The alternative — one `assigned_to_id` column plus an `assigned_to_type`
discriminator — is more compact but gives up foreign keys entirely (a single
column cannot reference two tables). Keeping two real FK columns means the
database guarantees the assignee actually exists. That mattered more than saving
a column.

A second `CHECK` keeps status and completion consistent: a task is `Completed`
if and only if `completed_on` is set.

### 4.3 How creator and assignee names are fetched

One query, three joins — no N+1 lookups, no second round-trip per task
(`src/repository.rs`):

```sql
SELECT
    ...,
    creator.name                      AS created_by,
    COALESCE(assignee.name, grp.name) AS assigned_to,
    CASE WHEN t.assigned_employee_id IS NOT NULL
         THEN 'employee' ELSE 'group' END AS assigned_to_type
FROM tasks AS t
INNER JOIN employees AS creator
        ON creator.id = t.created_by_id
LEFT JOIN employees AS assignee
        ON assignee.id = t.assigned_employee_id
LEFT JOIN employee_groups AS grp
        ON grp.id = t.assigned_group_id
WHERE t.parent_task_id = ?
```

- `creator` is an **INNER JOIN**: every task has a creator, so a missing match
  would be corrupt data, not a normal case.
- `assignee` and `grp` are **LEFT JOINs**, because on any given row only one of
  them matches — the other side is `NULL` by design.
- `COALESCE` picks whichever of the two names is present, giving a single
  `assigned_to` field. `employees` is joined twice under different aliases
  (`creator` and `assignee`) for two different purposes.
- The `CASE` expression reports which of the two it was.

### 4.4 How `parent_task_id = 0` is filtered

The filter is in the `WHERE` clause, so MySQL never sends sub-task rows over the
wire (and uses `idx_tasks_parent` to find them):

```sql
WHERE t.parent_task_id = ?
```

The value is **bound as a parameter**, not string-concatenated into the SQL:

```rust
pub const ROOT_PARENT_TASK_ID: u64 = 0;

sqlx::query_as::<_, TaskRow>(LIST_PARENT_TASKS_SQL)
    .bind(ROOT_PARENT_TASK_ID)
    .fetch_all(pool)
    .await
```

The dummy data has 12 parent tasks and 5 sub-tasks (ids 201–205), so a correct
response has `"count": 12` and contains no id in the 200s. To check the same
thing straight from MySQL, run `sql/03_api_query.sql`.

### 4.5 How the Rust code connects to MySQL

1. `dotenvy::dotenv()` loads `.env` in development; real environment variables
   override it (`src/main.rs`).
2. `Config::from_env()` reads `DATABASE_URL`, `SERVER_ADDR` and
   `DB_MAX_CONNECTIONS`. `DATABASE_URL` is mandatory — the app refuses to boot
   without it instead of falling back to guessed credentials (`src/config.rs`).
3. `db::create_pool()` builds a `MySqlPoolOptions` pool with a bounded
   connection count and a 5-second acquire timeout, then runs `SELECT 1` to fail
   fast at start-up rather than returning 500s on the first request
   (`src/db.rs`).
4. The pool is stored as Axum state (`.with_state(pool)`). It is an `Arc`
   internally, so each handler clones it cheaply and reuses pooled connections
   instead of opening a new one per request.
5. Handlers pull it out with `State(pool)` and pass it to the repository.

Queries use the runtime-checked `sqlx::query_as` rather than the compile-time
`query_as!` macro, deliberately: the macro needs a live database (or a prepared
offline cache) at *compile* time, which makes `cargo build` fail on a fresh
checkout before the database exists. Runtime binding keeps the build
self-contained; `FromRow` on `TaskRow` still maps columns to typed Rust fields,
and all parameters are still bound, so there is no SQL-injection surface.

---

## 5. Project structure

```
tasklist/
├── Cargo.toml
├── .env.example            # template — copy to .env, never committed
├── .gitignore
├── README.md
├── sql/
│   ├── 00_app_user.sql     # optional non-root MySQL user
│   ├── 01_schema.sql       # database + tables + constraints
│   ├── 02_dummy_data.sql   # 6 employees, 3 groups, 17 tasks
│   └── 03_api_query.sql    # the endpoint's query, runnable in the MySQL client
└── src/
    ├── main.rs             # start-up: env -> pool -> router -> listen
    ├── config.rs           # environment configuration
    ├── db.rs               # connection pool
    ├── error.rs            # AppError -> JSON HTTP response
    ├── models.rs           # TaskRow (DB) and TaskResponse (JSON)
    ├── repository.rs       # all SQL
    └── handlers.rs         # HTTP handlers
```

The layering is deliberate: `handlers` know HTTP but no SQL, `repository` knows
SQL but no HTTP, and `models` keeps the database row type separate from the JSON
contract so a column rename does not silently change the API.

---

## 6. Troubleshooting

| Problem | Fix |
| ------- | --- |
| `DATABASE_URL is not set` | Copy `.env.example` to `.env` and fill it in. |
| `could not connect to MySQL` | Check the MySQL service is running and the user/password in `DATABASE_URL` are correct. |
| `Unknown database 'tasklist'` | Run `sql/01_schema.sql` first. |
| `check constraint is violated` | A task must have exactly one of `assigned_employee_id` / `assigned_group_id`, and `completed_on` set only when status is `Completed`. |
| Empty `data` array | Run `sql/02_dummy_data.sql`. |
| A `@` or `#` in the DB password | URL-encode it in `DATABASE_URL` (`@` → `%40`, `#` → `%23`). |
