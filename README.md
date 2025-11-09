# Sortio

Minimal Plug-based API.

## Setup

```bash
mix deps.get
```

## Run

```bash
mix run --no-halt
```

Server starts on `http://localhost:4000`

## Test

```bash
mix test
```

## Endpoints

### Health
- `GET /health` - Health check

### Authentication
- `POST /register` - Register new user
- `POST /login` - Login and receive JWT token

### Users
- `GET /me` - Get current user info (authenticated)

### Raffles
- `GET /raffles` - List raffles (supports pagination and status filtering)
- `GET /raffles/:id` - Get raffle details
- `POST /raffles` - Create raffle (authenticated)
- `PUT /raffles/:id` - Update raffle (authenticated, owner only)
- `DELETE /raffles/:id` - Delete raffle (authenticated, owner only)
- `GET /raffles/:raffle_id/participants` - List raffle participants (paginated)
- `POST /raffles/:raffle_id/participants` - Join a raffle
- `DELETE /raffles/:raffle_id/participants/me` - Leave a raffle
