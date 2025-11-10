# This list is not exhaustive

## Other possible features
- On demand draw execution
- Draw from a custom list

## Scaling
- Cursor-based pagination
- Batch writes
- DB sharding


## Not implemented but needed for PROD
- Raffle state machine validation
- Email verification
- Password reset
- Token expiration and invalidation
- Refresh tokens
- Rate limiting on login
- Account lockout after failed attempts
- CORS headers (needed for use with frontend apps)
- Limit number of participants per raffle
- Soft deletes for participant records


## Common Mistakes Avoided
- Plain text passwords - Never store, always hash
- Returning password_hash - Security leak
- Hardcoded secrets in prod - Use ENV vars
- Not using Sandbox in tests - Tests pollute each other
- Revealing if email exists - User enumeration attack
- Logging PII in logs - Violates data privacy (LGDP, GDPR, etc.)
- N+1 query issues - Inconsistent preloading
- Cascade delete data loss - Using :delete_all can orphan data
- Missing database indexes - Queries on unindexed columns are slow
- Business logic in presentation layer - Keep router thin, logic in contexts
- Missing pagination - Unbounded queries exhaust resources at scale
