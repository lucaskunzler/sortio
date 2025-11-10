# Sortio

A minimal raffle/lottery management API built with Elixir and Plug.

## Features

- **User Management**: Register, login with JWT authentication
- **Raffle Management**: Create, update, delete raffles with owner permissions
- **Participant System**: Join/leave raffles with pagination support
- **Automatic Winner Drawing**: Background job draws winners when raffle closes
- **RESTful API**: Clean REST endpoints with status filtering and pagination
- **API Documentation**: Interactive Swagger UI documentation

## Architecture

```
├── lib/
│   ├── sortio/                   # Core business logic
│   │   ├── accounts/             # User management
│   │   ├── raffles/              # Raffle & participant logic
│   │   ├── workers/              # Oban background jobs
│   │   └── repo.ex               # Ecto repository
│   └── sortio_api/               # HTTP layer
│       ├── controllers/          # Request handlers
│       ├── views/                # Response serializers
│       ├── plugs/                # Middleware
│       └── router.ex             # Route definitions
```

**Tech Stack**: Elixir, Plug, Ecto, PostgreSQL, Guardian (JWT), Oban (jobs)

## Setup

### Prerequisites
- Elixir 1.19+
- PostgreSQL

### Installation

1. Install dependencies:
```bash
mix deps.get
```

2. Configure dev and test database on `config/dev.exs` and `config/test.exs`

3. Create and migrate database:
```bash
mix ecto.create
mix ecto.migrate
```

## Run

Start the server:
```bash
mix run --no-halt
```

Server runs on `http://localhost:4000`

### Quick Demo

Run `./demo.sh` to see an automated demo (creates 10 users, a raffle, and draws a winner in a few seconds).

## Example Usage

See full documentation at [./API.md](API.md)

### Register & Login
```bash
# Register (returns token for immediate use)
curl -X POST http://localhost:4000/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"secret123","name":"John Doe"}'
# Returns: {"token": "eyJhbGc...", "user": {...}}

# Login
curl -X POST http://localhost:4000/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"secret123"}'
# Returns: {"token": "eyJhbGc...", "user": {...}}
```

### Create & Manage Raffle
```bash
# Create raffle (authenticated)
curl -X POST http://localhost:4000/raffles \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"title":"Win a Prize","description":"Enter to win","draw_date":"2025-12-31T23:59:59Z"}'

# List raffles (public, supports ?status=active&page=1&limit=10)
curl http://localhost:4000/raffles

# Join raffle (authenticated)
curl -X POST http://localhost:4000/raffles/RAFFLE_ID/participants \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Testing

Run tests:
```bash
mix test
```
