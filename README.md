# PostgreSQL IMDB Top 1000 Movies

This project sets up a PostgreSQL database with IMDB Top 1000 movies data.

## Quick Start

### 1. Start PostgreSQL

```bash
make up
```

This will start the PostgreSQL container in the background using Docker Compose.

### 2. Load the IMDB data

```bash
./load_imdb_data.sh
```

This script will:
- Create the `imdb_movies` table
- Load all 1000 movies from the CSV file
- Display the count of loaded records

## Other Commands

- **Stop the database**: `make down`
- **View logs**: `make logs`
- **Restart**: `make restart`
- **Clean up (removes data)**: `make clean`

## Database Connection

- **Host**: localhost
- **Port**: 5432
- **Database**: postgres_text
- **Username**: postgres
- **Password**: password

## Data Structure

The `imdb_movies` table contains:
- Movie titles, release years, ratings
- Directors and main cast
- Genres, runtime, certificates
- IMDB ratings and vote counts
- Box office gross earnings