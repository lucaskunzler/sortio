#!/bin/bash

# Demo script for Sortio Raffle System
# This script creates 30 users, a raffle, has users join, and shows the winner

set -e

# Configuration
API_URL="${API_URL:-http://localhost:4000}"
NUM_USERS=10
DRAW_DELAY_SECONDS=2

# Generate unique timestamp for this demo run
TIMESTAMP=$(date +%s)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Sortio Raffle System Demo${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if API is running
echo -e "${YELLOW}Checking API health...${NC}"
if ! curl -s "${API_URL}/health" > /dev/null 2>&1; then
    echo -e "${RED}Error: API is not running at ${API_URL}${NC}"
    echo "Please start the API server first."
    exit 1
fi
echo -e "${GREEN}✓ API is running${NC}"
echo ""

# Step 1: Create 30 users
echo -e "${YELLOW}Step 1: Creating ${NUM_USERS} users...${NC}"
declare -a USER_TOKENS
declare -a USER_NAMES

for i in $(seq 1 $NUM_USERS); do
    USER_NAME="User${i}"
    USER_EMAIL="user${i}.${TIMESTAMP}@demo.com"
    USER_PASSWORD="password${i}"

    RESPONSE=$(curl -s -X POST "${API_URL}/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${USER_NAME}\",
            \"email\": \"${USER_EMAIL}\",
            \"password\": \"${USER_PASSWORD}\"
        }")

    TOKEN=$(echo $RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

    if [ -z "$TOKEN" ]; then
        echo -e "${RED}Error creating user ${USER_NAME}${NC}"
        echo "Response: $RESPONSE"
        exit 1
    fi

    USER_TOKENS[$i]=$TOKEN
    USER_NAMES[$i]=$USER_NAME

    echo -e "${GREEN}✓ Created ${USER_NAME} (${USER_EMAIL})${NC}"
done

echo -e "${GREEN}✓ All ${NUM_USERS} users created successfully${NC}"
echo ""

# Step 2: Create a raffle with draw date in 30 seconds
echo -e "${YELLOW}Step 2: Creating raffle...${NC}"

# Calculate draw date (30 seconds from now)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DRAW_DATE=$(date -u -v+${DRAW_DELAY_SECONDS}S +"%Y-%m-%dT%H:%M:%SZ")
else
    # Linux
    DRAW_DATE=$(date -u -d "+${DRAW_DELAY_SECONDS} seconds" +"%Y-%m-%dT%H:%M:%SZ")
fi

RAFFLE_RESPONSE=$(curl -s -X POST "${API_URL}/raffles" \
    -H "Authorization: Bearer ${USER_TOKENS[1]}" \
    -H "Content-Type: application/json" \
    -d "{
        \"title\": \"Demo Raffle - $(date +%Y-%m-%d\ %H:%M:%S)\",
        \"description\": \"A demo raffle with ${NUM_USERS} participants. Winner will be drawn in ${DRAW_DELAY_SECONDS} seconds!\",
        \"draw_date\": \"${DRAW_DATE}\"
    }")

RAFFLE_ID=$(echo $RAFFLE_RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
RAFFLE_TITLE=$(echo $RAFFLE_RESPONSE | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$RAFFLE_ID" ]; then
    echo -e "${RED}Error creating raffle${NC}"
    echo "Response: $RAFFLE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Raffle created:${NC}"
echo -e "  ID: ${RAFFLE_ID}"
echo -e "  Title: ${RAFFLE_TITLE}"
echo -e "  Draw Date: ${DRAW_DATE}"
echo ""

# Step 3: Have all users join the raffle
echo -e "${YELLOW}Step 3: All users joining the raffle...${NC}"

for i in $(seq 1 $NUM_USERS); do
    RESPONSE=$(curl -s -X POST "${API_URL}/raffles/${RAFFLE_ID}/participants" \
        -H "Authorization: Bearer ${USER_TOKENS[$i]}" \
        -H "Content-Type: application/json" \
        -d '{}')

    if echo "$RESPONSE" | grep -q '"error"'; then
        echo -e "${RED}✗ ${USER_NAMES[$i]} failed to join${NC}"
        echo "  Error: $RESPONSE"
    else
        echo -e "${GREEN}✓ ${USER_NAMES[$i]} joined the raffle${NC}"
    fi
done

echo -e "${GREEN}✓ All users joined successfully${NC}"
echo ""

# Show participant count
echo -e "${YELLOW}Fetching participant list...${NC}"
PARTICIPANTS_RESPONSE=$(curl -s "${API_URL}/raffles/${RAFFLE_ID}/participants?page_size=100")
PARTICIPANT_COUNT=$(echo $PARTICIPANTS_RESPONSE | grep -o '"total_count":[0-9]*' | cut -d':' -f2)

echo -e "${GREEN}✓ Total participants: ${PARTICIPANT_COUNT}${NC}"
echo ""

# Step 4: Wait for draw date
echo -e "${YELLOW}Step 4: Waiting ${DRAW_DELAY_SECONDS} seconds for draw date...${NC}"
echo -e "${BLUE}Drawing winner in:${NC}"

for i in $(seq $DRAW_DELAY_SECONDS -1 1); do
    echo -ne "\r  ${i} seconds remaining..."
    sleep 1
done
echo ""
echo -e "${GREEN}✓ Draw time reached!${NC}"
echo ""

# Step 5: Draw winner (you'll need to trigger the draw via your system)
echo -e "${YELLOW}Step 5: Drawing winner...${NC}"
echo -e "${BLUE}Waiting for Oban worker to process the draw...${NC}"

# Wait an extra moment to ensure the draw has been processed
sleep 1
echo ""

# Check winner
echo -e "${YELLOW}Checking winner...${NC}"
WINNER_RESPONSE=$(curl -s "${API_URL}/raffles/${RAFFLE_ID}/winner")

if echo "$WINNER_RESPONSE" | grep -q '"error"'; then
    ERROR_MSG=$(echo $WINNER_RESPONSE | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}Error: ${ERROR_MSG}${NC}"
    echo ""
    echo -e "${YELLOW}This might mean:${NC}"
    echo "  1. The raffle hasn't been drawn yet (no automatic draw mechanism)"
    echo "  2. The draw job hasn't run yet"
    echo ""
    echo -e "${BLUE}You can manually check the winner later with:${NC}"
    echo "  curl ${API_URL}/raffles/${RAFFLE_ID}/winner"
else
    WINNER_NAME=$(echo $WINNER_RESPONSE | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
    WINNER_EMAIL=$(echo $WINNER_RESPONSE | grep -o '"email":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ "$WINNER_NAME" == "null" ] || [ -z "$WINNER_NAME" ]; then
        echo -e "${YELLOW}⚠ Raffle was drawn but there was no winner (no participants)${NC}"
    else
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}🎉 WINNER ANNOUNCEMENT 🎉${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "  Name: ${WINNER_NAME}"
        echo -e "  Email: ${WINNER_EMAIL}"
        echo -e "${GREEN}========================================${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Raffle Details:${NC}"
echo "  Raffle ID: ${RAFFLE_ID}"
echo "  API URL: ${API_URL}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  # View raffle details"
echo "  curl ${API_URL}/raffles/${RAFFLE_ID}"
echo ""
echo "  # View participants"
echo "  curl ${API_URL}/raffles/${RAFFLE_ID}/participants"
echo ""
echo "  # Check winner"
echo "  curl ${API_URL}/raffles/${RAFFLE_ID}/winner"
echo ""
