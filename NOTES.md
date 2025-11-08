## Common Mistakes
Plain text passwords - Never store, always hash
Returning password_hash - Security leak
Hardcoded secrets in prod - Use ENV vars
Not using Sandbox in tests - Tests pollute each other
Revealing if email exists - User enumeration attack
Logging PII in logs - Violates data privacy (LGDP, GDPR, etc.)

## Not implemented now
- Email verification
- Password reset
- Refresh tokens
- Rate limiting on login
- Account lockout after failed attempts
