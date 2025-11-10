# API Documentation

This document describes all available API endpoints for the Sortio raffle system.

## Base URL

```
http://localhost:4000
```

## Authentication

Most endpoints require authentication using JWT Bearer tokens. Include the token in the Authorization header:

```
Authorization: Bearer <your_jwt_token>
```

Tokens are obtained from the `/register` or `/login` endpoints.

---

## Endpoints

### Health Check

#### Check API Health
- **Endpoint:** `GET /health`
- **Authentication:** Not required
- **Description:** Check if the API is running

**Example Request:**
```bash
curl http://localhost:4000/health
```

**Example Response:**
```json
{
  "status": "ok"
}
```

---

## Authentication

### Register User
- **Endpoint:** `POST /register`
- **Authentication:** Not required
- **Description:** Create a new user account and receive a JWT token

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "secure_password123"
}
```

**Example Request:**
```bash
curl -X POST http://localhost:4000/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "secure_password123"
  }'
```

**Success Response (201):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "John Doe",
    "email": "john@example.com",
    "inserted_at": "2024-01-01T12:00:00Z"
  }
}
```

**Error Response (422):**
```json
{
  "error": "Email has already been taken"
}
```

---

### Login User
- **Endpoint:** `POST /login`
- **Authentication:** Not required
- **Description:** Authenticate user and receive a JWT token

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "secure_password123"
}
```

**Example Request:**
```bash
curl -X POST http://localhost:4000/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "secure_password123"
  }'
```

**Success Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "John Doe",
    "email": "john@example.com",
    "inserted_at": "2024-01-01T12:00:00Z"
  }
}
```

**Error Response (400):**
```json
{
  "error": "Invalid email or password"
}
```

---

### Get Current User
- **Endpoint:** `GET /me`
- **Authentication:** Required
- **Description:** Get information about the currently authenticated user

**Example Request:**
```bash
curl http://localhost:4000/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Success Response (200):**
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "John Doe",
    "email": "john@example.com",
    "inserted_at": "2024-01-01T12:00:00Z"
  }
}
```

**Error Response (401):**
```json
{
  "error": "Unauthorized"
}
```

---

## Raffles

### List Raffles
- **Endpoint:** `GET /raffles`
- **Authentication:** Not required
- **Description:** Get a paginated list of raffles

**Query Parameters:**
- `page` (integer, optional, default: 1) - Page number
- `page_size` (integer, optional, default: 20) - Items per page
- `status` (string, optional) - Filter by status: `open`, `closed`, or `drawn`

**Example Request:**
```bash
# Get all raffles
curl http://localhost:4000/raffles

# Get page 2 with 10 items per page
curl http://localhost:4000/raffles?page=2&page_size=10

# Get only open raffles
curl http://localhost:4000/raffles?status=open
```

**Success Response (200):**
```json
{
  "raffles": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Grand Prize Raffle",
      "description": "Win an amazing prize!",
      "status": "open",
      "draw_date": "2024-12-31T23:59:59Z",
      "inserted_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z",
      "creator": {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "name": "Jane Smith"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_count": 50,
    "total_pages": 3
  }
}
```

---

### Get Raffle Details
- **Endpoint:** `GET /raffles/:id`
- **Authentication:** Not required
- **Description:** Get details of a specific raffle

**Path Parameters:**
- `id` (UUID, required) - Raffle ID

**Example Request:**
```bash
curl http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000
```

**Success Response (200):**
```json
{
  "raffle": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Grand Prize Raffle",
    "description": "Win an amazing prize!",
    "status": "open",
    "draw_date": "2024-12-31T23:59:59Z",
    "inserted_at": "2024-01-01T12:00:00Z",
    "updated_at": "2024-01-01T12:00:00Z",
    "creator": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "name": "Jane Smith"
    }
  }
}
```

**Error Response (404):**
```json
{
  "error": "Raffle not found"
}
```

---

### Create Raffle
- **Endpoint:** `POST /raffles`
- **Authentication:** Required
- **Description:** Create a new raffle

**Request Body:**
```json
{
  "title": "Grand Prize Raffle",
  "description": "Win an amazing prize!",
  "draw_date": "2024-12-31T23:59:59Z"
}
```

All fields are optional.

**Example Request:**
```bash
curl -X POST http://localhost:4000/raffles \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Grand Prize Raffle",
    "description": "Win an amazing prize!",
    "draw_date": "2024-12-31T23:59:59Z"
  }'
```

**Success Response (201):**
```json
{
  "raffle": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Grand Prize Raffle",
    "description": "Win an amazing prize!",
    "status": "open",
    "draw_date": "2024-12-31T23:59:59Z",
    "inserted_at": "2024-01-01T12:00:00Z",
    "updated_at": "2024-01-01T12:00:00Z",
    "creator": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "name": "Jane Smith"
    }
  }
}
```

**Error Response (422):**
```json
{
  "error": "Validation error message"
}
```

---

### Update Raffle
- **Endpoint:** `PUT /raffles/:id`
- **Authentication:** Required
- **Authorization:** Must be the raffle owner
- **Description:** Update an existing raffle

**Path Parameters:**
- `id` (UUID, required) - Raffle ID

**Request Body:**
```json
{
  "title": "Updated Raffle Title",
  "description": "Updated description",
  "draw_date": "2024-12-31T23:59:59Z"
}
```

All fields are optional.

**Example Request:**
```bash
curl -X PUT http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated Raffle Title",
    "description": "Updated description"
  }'
```

**Success Response (200):**
```json
{
  "raffle": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Updated Raffle Title",
    "description": "Updated description",
    "status": "open",
    "draw_date": "2024-12-31T23:59:59Z",
    "inserted_at": "2024-01-01T12:00:00Z",
    "updated_at": "2024-01-02T10:30:00Z",
    "creator": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "name": "Jane Smith"
    }
  }
}
```

**Error Response (403):**
```json
{
  "error": "You are not authorized to update this raffle"
}
```

---

### Delete Raffle
- **Endpoint:** `DELETE /raffles/:id`
- **Authentication:** Required
- **Authorization:** Must be the raffle owner
- **Description:** Delete a raffle

**Path Parameters:**
- `id` (UUID, required) - Raffle ID

**Example Request:**
```bash
curl -X DELETE http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Success Response (204):**
No content returned.

**Error Response (403):**
```json
{
  "error": "You are not authorized to delete this raffle"
}
```

**Error Response (404):**
```json
{
  "error": "Raffle not found"
}
```

---

## Participants

### List Raffle Participants
- **Endpoint:** `GET /raffles/:raffle_id/participants`
- **Authentication:** Not required
- **Description:** Get a paginated list of participants for a raffle

**Path Parameters:**
- `raffle_id` (UUID, required) - Raffle ID

**Query Parameters:**
- `page` (integer, optional, default: 1) - Page number
- `page_size` (integer, optional, default: 20) - Items per page

**Example Request:**
```bash
# Get all participants for a raffle
curl http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000/participants

# Get page 2 with 10 items per page
curl http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000/participants?page=2&page_size=10
```

**Success Response (200):**
```json
{
  "participants": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440003",
      "raffle_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "660e8400-e29b-41d4-a716-446655440001",
      "inserted_at": "2024-01-01T14:30:00Z",
      "user": {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "name": "John Doe"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_count": 50,
    "total_pages": 3
  }
}
```

**Error Response (404):**
```json
{
  "error": "Raffle not found"
}
```

---

### Join Raffle
- **Endpoint:** `POST /raffles/:raffle_id/participants`
- **Authentication:** Required
- **Description:** Join a raffle as a participant

**Path Parameters:**
- `raffle_id` (UUID, required) - Raffle ID

**Request Body:**
Empty or `{}`

**Example Request:**
```bash
curl -X POST http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000/participants \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Success Response (201):**
```json
{
  "participant": {
    "id": "770e8400-e29b-41d4-a716-446655440003",
    "raffle_id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "660e8400-e29b-41d4-a716-446655440001",
    "inserted_at": "2024-01-01T14:30:00Z",
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "name": "John Doe",
      "email": "john@example.com"
    }
  }
}
```

**Error Response (409):**
```json
{
  "error": "User already participating in this raffle"
}
```

**Error Response (422):**
```json
{
  "error": "Cannot join raffle after draw date"
}
```

---

### Leave Raffle
- **Endpoint:** `DELETE /raffles/:raffle_id/participants/me`
- **Authentication:** Required
- **Description:** Remove yourself from a raffle

**Path Parameters:**
- `raffle_id` (UUID, required) - Raffle ID

**Example Request:**
```bash
curl -X DELETE http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000/participants/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Success Response (204):**
No content returned.

**Error Response (404):**
```json
{
  "error": "Participant not found"
}
```

---

## Winner

### Get Raffle Winner
- **Endpoint:** `GET /raffles/:id/winner`
- **Authentication:** Not required
- **Description:** Get the winner of a drawn raffle

**Path Parameters:**
- `id` (UUID, required) - Raffle ID

**Example Request:**
```bash
curl http://localhost:4000/raffles/550e8400-e29b-41d4-a716-446655440000/winner
```

**Success Response (200) - With Winner:**
```json
{
  "raffle_id": "550e8400-e29b-41d4-a716-446655440000",
  "raffle_title": "Grand Prize Raffle",
  "winner": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "name": "John Doe",
    "email": "john@example.com",
    "inserted_at": "2024-01-01T12:00:00Z"
  },
  "drawn_at": "2024-12-31T23:59:59Z"
}
```

**Success Response (200) - No Winner (no participants):**
```json
{
  "raffle_id": "550e8400-e29b-41d4-a716-446655440000",
  "raffle_title": "Grand Prize Raffle",
  "winner": null,
  "drawn_at": "2024-12-31T23:59:59Z"
}
```

**Error Response (422):**
```json
{
  "error": "Raffle has not been drawn yet"
}
```

**Error Response (404):**
```json
{
  "error": "Raffle not found"
}
```

---

## Error Responses

All error responses follow this format:
```json
{
  "error": "Error message describing the issue"
}
```

### Common HTTP Status Codes

- `200 OK` - Request succeeded
- `201 Created` - Resource created successfully
- `204 No Content` - Request succeeded with no response body
- `400 Bad Request` - Invalid request parameters or format
- `401 Unauthorized` - Authentication required or invalid token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `409 Conflict` - Constraint violation (e.g., duplicate participation)
- `422 Unprocessable Entity` - Validation error

---

## Complete Example: User Journey

Here's a complete example showing a typical user journey:

### 1. Register a new user
```bash
curl -X POST http://localhost:4000/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice",
    "email": "alice@example.com",
    "password": "securepass123"
  }'
```

Save the returned token for subsequent requests.

### 2. Create a raffle
```bash
curl -X POST http://localhost:4000/raffles \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "New Year Raffle",
    "description": "Win exciting prizes!",
    "draw_date": "2024-12-31T23:59:59Z"
  }'
```

Save the raffle ID from the response.

### 3. Join the raffle (as another user)
```bash
curl -X POST http://localhost:4000/raffles/RAFFLE_ID_HERE/participants \
  -H "Authorization: Bearer ANOTHER_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### 4. List all participants
```bash
curl http://localhost:4000/raffles/RAFFLE_ID_HERE/participants
```

### 5. Check the winner (after draw)
```bash
curl http://localhost:4000/raffles/RAFFLE_ID_HERE/winner
```

---
