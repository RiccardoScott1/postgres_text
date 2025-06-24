make index from title and overview

```sql
CREATE INDEX imdb_movies_idx ON imdb_movies USING GIN (to_tsvector('english', series_title || ' ' || overview));
```


```sql
ALTER TABLE imdb_movies
ADD COLUMN textsearchable_index_col tsvector
GENERATED ALWAYS AS (
  to_tsvector('english', coalesce(series_title, '') || ' ' || coalesce(overview, ''))
) STORED;

CREATE INDEX textsearch_idx 
ON imdb_movies USING GIN (textsearchable_index_col);
```


✅ Pros:
Stored once, indexed once: PostgreSQL computes the tsvector once when the row is inserted or updated — not at query time.

Faster queries: Queries using the index can skip recomputing the tsvector.

Reusable: You can reference textsearchable_index_col in queries, views, triggers, etc.

More transparent: Easier to debug and inspect the stored vector.

❌ Cons:
Schema complexity: Adds an extra column to the table.

Slightly more storage: The column is stored physically, increasing disk usage.

Harder to change logic: Changing how the tsvector is generated requires dropping and recreating the column.

Weighted version:

```sql
ALTER TABLE imdb_movies
ADD COLUMN textsearchable_index_col_weighted tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('english', coalesce(series_title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(overview, '')), 'B')
) STORED;

CREATE INDEX textsearch_idx_weighted 
ON imdb_movies USING GIN (textsearchable_index_col_weighted);
```


