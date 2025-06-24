#!/bin/bash

# Load environment variables
source .env

# Database connection parameters
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="$POSTGRES_DB"
DB_USER="$POSTGRES_USER"
DB_PASSWORD="$POSTGRES_PASSWORD"

# Export password for psql
export PGPASSWORD="$DB_PASSWORD"

echo "Creating IMDB movies table and loading data..."

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

echo "Data loading completed!"