#!/bin/bash

# Exit on any error
set -e

# Function to handle errors
handle_error() {
    echo "❌ Error occurred on line $1"
    echo "❌ Data loading failed!"
    exit 1
}

# Trap errors
trap 'handle_error $LINENO' ERR

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

# Database connection parameters
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="$POSTGRES_DB"
DB_USER="$POSTGRES_USER"
DB_PASSWORD="$POSTGRES_PASSWORD"

# Validate required environment variables
if [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ Error: Missing required environment variables (POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD)"
    exit 1
fi

# Check if CSV file exists
if [ ! -f "data/imdb_top_1000.csv" ]; then
    echo "❌ Error: data/imdb_top_1000.csv not found"
    exit 1
fi

# Export password for psql
export PGPASSWORD="$DB_PASSWORD"

echo "🔄 Creating IMDB movies table and loading data..."

# Test database connection
echo "🔍 Testing database connection..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' >/dev/null 2>&1; then
    echo "❌ Error: Cannot connect to database. Make sure PostgreSQL is running and credentials are correct."
    exit 1
fi

echo "✅ Database connection successful"

# SQL to create table and load data
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
-- Drop table if exists
DROP TABLE IF EXISTS imdb_movies;

-- Create table matching CSV structure
CREATE TABLE imdb_movies (
    id SERIAL PRIMARY KEY,
    poster_link TEXT,
    series_title VARCHAR(255),
    released_year TEXT,
    certificate VARCHAR(10),
    runtime VARCHAR(20),
    genre VARCHAR(100),
    imdb_rating DECIMAL(3,1),
    overview TEXT,
    meta_score TEXT,
    director VARCHAR(100),
    star1 VARCHAR(100),
    star2 VARCHAR(100),
    star3 VARCHAR(100),
    star4 VARCHAR(100),
    no_of_votes TEXT,
    gross VARCHAR(20)
);

-- Load data from CSV
\COPY imdb_movies(poster_link, series_title, released_year, certificate, runtime, genre, imdb_rating, overview, meta_score, director, star1, star2, star3, star4, no_of_votes, gross) FROM 'data/imdb_top_1000.csv' WITH CSV HEADER;

-- Show count of loaded records
SELECT COUNT(*) as total_movies FROM imdb_movies;

-- Show first few records
SELECT series_title, released_year, imdb_rating, director FROM imdb_movies LIMIT 5;
EOF

# Check if the loading was successful
RECORD_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM imdb_movies;" 2>/dev/null | tr -d ' ')

if [ "$RECORD_COUNT" -eq 1000 ]; then
    echo "✅ Data loading completed successfully! Loaded $RECORD_COUNT movies."
elif [ "$RECORD_COUNT" -gt 0 ]; then
    echo "⚠️  Data loading completed with warnings. Loaded $RECORD_COUNT movies (expected 1000)."
else
    echo "❌ Data loading failed! No records found in database."
    exit 1
fi