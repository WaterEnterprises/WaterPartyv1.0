# GEMINI.md

## Project Overview
**WaterParty** is a premium, full-stack party-matching application ("Human Connection OS") designed for seamless event discovery and real-time social interaction. 

- **Frontend:** Flutter-based mobile and desktop application featuring a modern glassmorphism UI and Frutiger typography.
- **Backend:** High-performance Go server optimized for low-latency WebSocket communication and PostgreSQL data persistence.

## Project Structure
```text
/root/WaterParty/
├── android/          # Android-specific native code
├── assets/           # Typography (Frutiger) and image assets
├── ios/              # iOS-specific native code
├── lib/              # Flutter source code
│   ├── auth.dart     # Authentication logic and screens
│   ├── main.dart     # App entry point and navigation scaffold
│   ├── providers.dart # Riverpod state management
│   └── websocket.dart # Real-time client-side service
├── server/           # Go backend source code
│   ├── main.go       # API routes and server initialization
│   ├── database.go   # Postgres/pgx integration
│   └── websocket.go  # Room-based WebSocket Hub logic
└── Makefile          # Centralized build and release automation
```

## Building and Running

### Prerequisites
- **Flutter SDK:** ^3.11.0
- **Go:** ^1.25.0
- **PostgreSQL:** Required for backend persistence.

### Key Commands
The project uses a `Makefile` to simplify common tasks:

- **Install Dependencies:** `make install-deps`
- **Build All (Native):** `make build` (Builds server binary and native app for the current OS)
- **Run Frontend:** `flutter run`
- **Run Backend:** `cd server && go run .`
- **Full Release:** `make release` (Builds artifacts for Android, Linux, Web, and multi-arch server binaries)
- **Clean Artifacts:** `make clean`

### Testing
- **Frontend:** `flutter test`
- **Backend:** `cd server && go test ./...` (Note: Ensure database environment is configured for integration tests).

## Development Conventions

### Frontend (Flutter)
- **State Management:** Rigorously use **Riverpod** (Notifier-based). Avoid `setState` in complex widgets.
- **Theming:** Adhere to `AppTheme.darkTheme` defined in `lib/theme.dart`.
- **UI Style:** Maintain the "Premium Glassmorphism" aesthetic with consistent gradients and blur effects.
- **Navigation:** Controlled via `navIndexProvider` in `MainScaffold`.

### Backend (Go)
- **Database:** Use `pgxpool` for connection management. Prefer raw SQL with `pgx` for performance over ORMs.
- **Concurrency:** Leverage Go routines for the WebSocket Hub and long-running tasks.
- **Error Handling:** Log errors with descriptive prefixes (e.g., `❌ Database connection error`).
- **Middleware:** All API handlers must be wrapped with `corsMiddleware`.

## Configuration
The backend requires the following environment variables:
- `DATABASE_URL`: PostgreSQL connection string.
- `PORT`: (Optional) Port to listen on (defaults to 8080).

## CI/CD
- **Production:** `CI.yml` triggers on `main`/`master` to generate full release artifacts.
- **Development:** `Dev-CI.yml` triggers on `dev`/`feature/*` for fast validation and ARM64/Linux builds.
