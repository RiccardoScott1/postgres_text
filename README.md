# PostgreSQL IMDB Top 1000 Movies

This project sets up a PostgreSQL database with IMDB Top 1000 movies data.

## Setup

### 1. Environment Configuration

Copy the example environment file and configure your PostgreSQL credentials:

```bash
cp .env.example .env
```

Edit `.env` to set your desired database credentials:
- `POSTGRES_DB`: Database name (default: postgres_text)
- `POSTGRES_USER`: Database username (default: postgres)  
- `POSTGRES_PASSWORD`: Database password (default: password)

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

## Make Commands

- **`make up`**: Start PostgreSQL container in the background
- **`make down`**: Stop and remove PostgreSQL container
- **`make logs`**: View real-time container logs
- **`make restart`**: Restart the PostgreSQL container
- **`make clean`**: Stop container, remove volumes, and clean Docker system
- **`make cleandata`**: Stop container and remove all PostgreSQL data files
- **`make fresh`**: Complete reset - removes data, starts container, and loads IMDB data

## Database Connection

Connection details use the values from your `.env` file:
- **Host**: localhost
- **Port**: 5432
- **Database**: Value of `POSTGRES_DB`
- **Username**: Value of `POSTGRES_USER`
- **Password**: Value of `POSTGRES_PASSWORD`

## Data Structure

The `imdb_movies` table contains:
- Movie titles, release years, ratings
- Directors and main cast
- Genres, runtime, certificates
- IMDB ratings and vote counts
- Box office gross earnings