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



```sql
SELECT 
  series_title, 
  overview,
  ts_rank(textsearchable_index_col_weighted, query) AS rank,
  ts_rank('{0.1, 0.1, 1.0, 0.1}', textsearchable_index_col_weighted, query) AS rank_weights_inverted
  --{0.1, 0.2, 0.4, 1.0} default weigths d,c,b,a
FROM
  imdb_movies, 
  plainto_tsquery('fish') query
WHERE query @@ textsearchable_index_col_weighted
ORDER BY rank DESC
LIMIT 10;
```

|series_title|overview|rank|rank_weights_inverted|
|------------|--------|----|---------------------|
|Big Fish|A frustrated son tries to determine the fact from fiction in his dying father's life.|0.6079271|0.06079271|
|The Bourne Identity|A man is picked up by a fishing boat, bullet-riddled and suffering from amnesia, before racing to elude assassins and attempting to regain his memory.|0.24317084|0.6079271|
