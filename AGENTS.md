# HOTEL MANAGEMENT SYSTEM — PROJECT RULES

These instructions apply to the entire hotel-management-system project.

## 1. Project purpose
Build a university Database Management Systems project for hotel operations, including room reservations, check-in/check-out, restaurant orders, invoicing, and revenue reporting.

## 2. Required technology stack
- Database: Microsoft SQL Server.
- SQL dialect: T-SQL only.
- Backend: Node.js with Express.js.
- Frontend: React with Vite.
- SQL Server driver for Node.js: `mssql`.
- API testing: Postman.
- Version control: Git and GitHub.

Do not switch to MySQL or PostgreSQL unless the project owner explicitly changes the requirement.

## 3. Architecture
Use this architecture:

React frontend → Express REST API → Microsoft SQL Server

- The React frontend must never connect directly to SQL Server.
- All database reads and writes must go through the backend API.
- Keep frontend, backend, and database scripts in clearly separated folders.
- Inspect the existing folder structure before creating or moving files.

## 4. Database design and SQL rules
- Use valid Microsoft SQL Server T-SQL syntax. Do not use MySQL-specific syntax such as `AUTO_INCREMENT`, `DELIMITER`, or `SIGNAL`.
- Use `IDENTITY(1,1)` for suitable generated integer primary keys.
- Use `DECIMAL(p,s)` for monetary values, not `FLOAT`.
- Use `DATE`, `TIME`, or `DATETIME2` appropriately.
- Define primary keys, foreign keys, `NOT NULL`, `UNIQUE`, and `CHECK` constraints where appropriate.
- Use consistent Vietnamese table and column names that match the approved ERD.
- Do not rename tables or columns without first explaining the impact and obtaining approval.
- Preserve historical prices: store the applicable room rate in the rental record and the food unit price in each order-detail record.
- Do not hard-delete records that are referenced by transactions; use an inactive/status field where appropriate.
- Use transactions for multi-step operations that must succeed or fail as one unit.
- Use `TRY...CATCH`, `COMMIT`, `ROLLBACK`, and `THROW` where appropriate.
- Prevent overlapping active reservations for the same room. A simple `CHECK` constraint is not sufficient; enforce this in a transaction-safe backend or stored procedure.
- Avoid storing duplicate calculated totals unless there is a clear snapshot/audit requirement.

## 5. Core business rules
- A room cannot have overlapping active reservations.
- A room cannot be checked into while occupied or otherwise unavailable.
- A walk-in guest must be supportable if the approved requirements allow it.
- Every restaurant order must be linked to a valid, active room rental.
- An order must not be added to a rental that has already been closed.
- A rental can have multiple restaurant order slips.
- A rental can have at most one final invoice.
- The invoice must account for room charges and restaurant charges.
- A paid invoice must not be paid again.
- Completing checkout must close the rental and release the room.
- Validate business rules in the backend and database layer, not only in the UI.

If a business rule is ambiguous, ask the project owner before implementing it.

## 6. Backend rules
- Use RESTful API conventions and appropriate HTTP status codes.
- Separate routes, controllers, services, and database configuration where practical.
- Use parameterized queries with the `mssql` library.
- Never concatenate raw user input into SQL statements.
- Keep credentials and secrets in environment variables (for example, `.env`).
- Never commit `.env`, passwords, API keys, or connection secrets.
- Provide consistent error responses and validate request data.
- Use database transactions for checkout/payment and other multi-step critical operations.
- Do not claim an endpoint works unless it has been run and tested.

## 7. Frontend rules
- Use React functional components and hooks.
- Organize pages and reusable components clearly.
- Keep API calls separate from presentation components where practical.
- Do not put database credentials or direct SQL connection code in the frontend.
- Validate forms and show loading, success, empty, and error states.
- Keep navigation, labels, and visual styling consistent.
- Do not use hard-coded fake data to imply that the backend is connected.

## 8. Collaboration and Git
- Follow the existing branch and pull-request workflow.
- Make focused changes in small, reviewable steps.
- Do not commit, push, merge, or delete branches without explicit approval from the user.
- Do not overwrite another member's work.
- Before editing shared database schema or API contracts, inspect the current version and explain breaking changes.
- Keep sample data and database scripts version-controlled, but never include real personal data or credentials.

## 9. Agent operating procedure
Before making changes:
1. Inspect the relevant files and current project structure.
2. Restate the task and identify the files likely to change.
3. For significant work, present a short implementation plan first.
4. Identify assumptions and ask questions when requirements are unclear.

While making changes:
1. Work only on the requested scope.
2. Preserve existing code and conventions unless there is a clear reason to change them.
3. Do not delete or rewrite files without explaining why.
4. Prefer simple, maintainable solutions suitable for a student team project.

After making changes:
1. List every file created or modified.
2. Explain what changed in plain Vietnamese.
3. Run relevant tests or commands when available.
4. Report test results honestly; distinguish tested behavior from unverified behavior.
5. Explain how the user can run or verify the result.

## 10. Communication
- Explain technical concepts in beginner-friendly Vietnamese.
- Keep code identifiers and standard technical terms in English where appropriate.
- Do not invent project files, database tables, API endpoints, test results, or successful execution.
- If the current environment cannot access the team's SQL Server instance, say so and provide the exact information needed to connect.
