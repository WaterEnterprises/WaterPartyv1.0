# 🌊 WaterParty - Human Connection OS

WaterParty is a premium, full-stack party-matching application designed for seamless event discovery and hosting. Built with a focus on high-performance real-time interactions and a sleek, modern aesthetic.

## 🚀 Tech Stack

### Frontend (Flutter)
- **Framework:** Flutter (Android, iOS, Web, Linux)
- **State Management:** Riverpod (Notifier-based)
- **Styling:** Premium glassmorphism UI with Frutiger typography.
- **Networking:** `http` for REST, `web_socket_channel` for real-time updates.
- **Local Persistence:** `sqflite` for secure session management.

### Backend (Go)
- **Language:** Go 1.26.0 (Optimized for low-latency concurrency)
- **Database:** PostgreSQL (Hosted on Render)
- **Driver:** `pgx` (Performance-first driver)
- **Real-time:** Custom WebSocket Hub with room-based routing.
- **Security:** `bcrypt` password hashing and environment-variable-only configuration.
- **Image Storage:** Custom hash-based binary storage within Postgres for optimized delivery.

## 📦 Build & Release (Makefile)

The project includes a robust `Makefile` for multi-platform releases.

- **Production Release:** `make release` (Builds all server binaries and app artifacts).
- **Development Release:** `make release-dev` (Fast builds: Android ARM64 + Linux x64 Server).
- **Cleanup:** `make clean`

## 🛠️ Environment Configuration

The Go server requires the following environment variables for production:

- `DATABASE_URL`: Full Postgres connection string (Internal for Render).
- `PORT`: Automatically set by Render (defaults to 8080).

## 🌍 CI/CD

Automated workflows are configured in GitHub Actions:
- **Production (`CI.yml`)**: Triggers on `main`/`master`. Updates the static `release` tag with full artifacts.
- **Development (`Dev-CI.yml`)**: Triggers on `dev`/`feature/*`. Updates the static `dev` tag with optimized build speeds (parallelized jobs).

## ✨ Key Features
- **Match Your Party:** Slogan-driven discovery feed.
- **Real-time Messaging:** Room-based and Pair-wise DM support.
- **Image Picking:** Integrated upload flow with server-side hash generation.
- **Multi-Step Onboarding:** Sophisticated user profiling for better matching.
- **Responsive Design:** Optimized for mobile (Android/iOS) and desktop (Linux).

---
*Built for the future of social interaction.*
