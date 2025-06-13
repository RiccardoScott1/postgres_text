# Full Text Search in PostgreSQL
**A quick tutorial**

**Abstract** 
In our detailed article on Full Text Search (FTS) in PostgreSQL we compare search-engines like Elasticsearch or Solr to PostgreSQL FTS, go through configurations, weighting, indexing, briefly explaining the GIN (Generalized Inverted Index), core functions, and ranking results. 

Here we want to give a quick tutorial on FTS with some real world exapmles.


TODO 
- Find a good dataset (text, abstract, title) (could use crawled results from some domain)


- show exaple record of raw text

## one tsvector just concat text

```sql
CREATE INDEX pgweb_idx ON pgweb USING GIN (to_tsvector('english', title || ' ' || body));
```
what's the difference to this????
```sql
ALTER TABLE pgweb
ADD COLUMN textsearchable_index_col tsvector
GENERATED ALWAYS AS (
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
) STORED;

CREATE INDEX textsearch_idx ON pgweb USING GIN (textsearchable_index_col);
```

## one with prefixed weigths


#### Assigning weights
You can also **assign weights** to different parts of a document to indicate their relative importance in ranking search results. 

PostgreSQL allows you to label tokens in the `tsvector` with weights `A`, `B`, `C`, or `D`, where `A` is considered the most important and `D` the least. This is especially useful when your document has structured fields/columns like a `title`, `body`, or `keywords`, and you want matches in more important fields (e.g., the title) to rank higher.
```sql
UPDATE documents SET fts_index =
  setweight(to_tsvector(coalesce(title, '')), 'A') ||
  setweight(to_tsvector(coalesce(body, '')), 'B');
```

In this example:

* `to_tsvector(coalesce(title, ''))` extracts search terms from the `title` field, and assigns them the highest weight `'A'`.
* `to_tsvector(coalesce(body, ''))` does the same for the `body` field but assigns a lower weight `'B'`.
* The `||` operator merges the two `tsvector` results into a single weighted index.

```sql
select 
    setweight(to_tsvector('i am very important'), 'A') || 
    setweight(to_tsvector('am I important as well?'), 'B');
-- returns: 'import':4A,7B 'well':9B
```

This strategy ensures that search results where the match occurs in the title will be considered more relevant than those with matches only in the body.




## config

set a default for your session or database:

```sql
SET default_text_search_config = 'english';
```


## query and ranking examples

### `to_tsquery`: Structured Query Parsing

`to_tsquery` builds a `tsquery` object from structured query text using operators like `&` (AND), `|` (OR), `!` (NOT), and `<->` (FOLLOWED BY). Tokens are normalized, and stop words are ignored.

**Example:**

```sql
SELECT to_tsquery('english', 'fat & rats');
-- 'fat' & 'rat'
```

Supports advanced features like weights and prefix matching:

```sql
SELECT to_tsquery('english', 'fat | rats:AB');
-- 'fat' | 'rat':AB  Matches the exact word 'fat' OR 'rat' with weight A or B only.
```

```sql
SELECT to_tsquery('english', 'supern:*A');
-- Matches any word that starts with "supern", like "supernova", "supernatural", but only if the weight is A.
```

The difference between `:*A` and `:A` in PostgreSQL lies in **prefix matching**.
- `:A` Matches lexemes that have **exact matches** and are tagged with **weight A**.
- `:*A` Matches **any lexeme that starts with the given prefix**, but **only if it's assigned weight A**.
Use `:*A` when you want **prefix-based fuzzy matching** **with a specific weight**.


### `plainto_tsquery`: Simple Text Queries

`plainto_tsquery` is ideal for quick searches without using operators. It automatically adds `&` between terms and ignores punctuation and special query syntax.

**Example:**

```sql
SELECT plainto_tsquery('english', 'The Fat Rats');
-- 'fat' & 'rat'
```
This function is great for user-entered text where no special logic is expected.

### `phraseto_tsquery`: Phrase Search

`phraseto_tsquery` behaves like `plainto_tsquery`, but it uses `<->` (FOLLOWED BY) to preserve word order, which is useful for searching phrases.

**Example:**

```sql
SELECT phraseto_tsquery('english', 'The Fat Rats');
-- 'fat' <-> 'rat'
```

It also retains stop word positions using `<N>` to denote gaps in sequences.

```sql
select phraseto_tsquery('english', 'The cat on the mat');
--'cat' <2> 'mat'
```
This helps maintain the phrase structure, allowing more accurate phrase searches even when stop words are present.

```sql
select 'cat is a mat' @@ phraseto_tsquery('english', 'The cat on the mat');
--returns true  because 'is a' are 2 stop words just like 'on the'
```


### `websearch_to_tsquery`: Search-Engine Style

`websearch_to_tsquery` is the most user-friendly and forgiving option. It uses syntax similar to popular search engines like Google or Bing.

**Supported syntax includes:**

* `"quoted text"` → phrase (`<->`)
* `-` → NOT (`!`)
* `or` → OR (`|`)
* Plain words → AND (`&`)

**Examples:**

```sql
SELECT websearch_to_tsquery('english', 'The fat rats');
-- 'fat' & 'rat'

SELECT websearch_to_tsquery('english', '"supernovae stars" -crab');
-- 'supernova' <-> 'star' & !'crab'

SELECT websearch_to_tsquery('english', '"sad cat" or "fat rat"');
-- 'sad' <-> 'cat' | 'fat' <-> 'rat'

SELECT websearch_to_tsquery('english', 'signal -"segmentation fault"');
-- 'signal' & !( 'segment' <-> 'fault' )
```

This is perfect for web apps where users expect flexible, natural search behavior without syntax errors.


Each of these functions supports different use cases, from structured filters to intuitive search interfaces. Together, they form the foundation of PostgreSQL's powerful and flexible full text search system.


## Ranking Results

**PostgreSQL offers two built-in ranking functions—`ts_rank` and `ts_rank_cd`—to assess the relevance of documents in full-text search results.** 
These functions account for factors such as term frequency, proximity, and document structure. 
While `ts_rank` focuses on frequency of matches, `ts_rank_cd` additionally considers how close the matching terms appear together (**c**over **d**ensity). 
```sql
ts_rank([ weights float4[], ] vector tsvector, query tsquery [, normalization integer ]) returns float4

ts_rank_cd([ weights float4[], ] vector tsvector, query tsquery [, normalization integer ]) returns float4
```

Both support weighting terms differently based on their position in the document (e.g., title vs. body): {D-weight, C-weight, B-weight, A-weight} default to {0.1, 0.2, 0.4, 1.0} .

Normalization options allow for adjusting relevance scores based on document length or word uniqueness: 

- 0 (the default) ignores the document length
- 1 divides the rank by 1 + the logarithm of the document length
- 2 divides the rank by the document length
- 4 divides the rank by the mean harmonic distance between extents (this is implemented only by ts_rank_cd)
- 8 divides the rank by the number of unique words in document
- 16 divides the rank by 1 + the logarithm of the number of unique words in document
- 32 divides the rank by itself + 1

One or more normalisation strategy flags can be specified using '|' (for example, 2|4), if more than one are specified, they are applied in order.

These functions provide a flexible foundation, and can also be extended or customized for domain-specific ranking needs.


In all examples below, assume a table `my_table` with the column `textsearch` of type `tsvector`, typically generated using `to_tsvector()` and indexed on relevant document fields (such as titles, abstracts, and content).

### Example Using `ts_rank`:**

The `ts_rank` function is useful for general-purpose ranking based on term frequency. 
The following query selects the top 10 most relevant documents for a search involving the terms *neutrino* or *dark matter*, using `ts_rank` to sort the results:

```sql
SELECT 
  title, 
  ts_rank(textsearch, query) AS rank
FROM
  my_table, 
  to_tsquery('neutrino | (dark & matter)') query
WHERE query @@ textsearch
ORDER BY rank DESC
LIMIT 10;
```
(In PostgreSQL the `,` in a from statement performs a cross-join.)

This will return a ranked list of documents where the most frequent and relevant term matches appear at the top.


### **Example Using `ts_rank_cd`:**

`ts_rank_cd` adds proximity into the scoring formula, favouring documents where the matched terms are closer together. This makes it ideal for more fine-grained ranking of results:

```sql
SELECT 
  title, 
  ts_rank_cd(textsearch, query) AS rank
FROM 
  my_table, 
  to_tsquery('neutrino | (dark & matter)') query
WHERE query @@ textsearch
ORDER BY rank DESC
LIMIT 10;
```

This function requires that the `tsvector` includes positional information (i.e. "'ate':9 'cat':3 'fat':2,11"), or it will return a score of zero. This nuance makes `ts_rank_cd` better suited for use cases where phrase or contextual proximity significantly impacts relevance.


### **Using Weights in Ranking Functions:**

Both `ts_rank` and `ts_rank_cd` support an optional `weights` argument. For example:

```sql
SELECT 
  title, 
  ts_rank_cd('{0.1, 0.2, 0.4, 1.0}', textsearch, query) AS rank
FROM 
  my_table, 
  to_tsquery('neutrino | (dark & matter)') query
WHERE query @@ textsearch
ORDER BY rank DESC
LIMIT 10;
```

Here, terms tagged with weight category `A` (typically used for titles) are given full weight (1.0), while those in category `D` (e.g., footnotes or less important sections) are given a lower influence (0.1). This allows tailoring ranking logic to reflect the structure and importance of various parts of the content.


## **Conclusion**

PostgreSQL’s Full Text Search (FTS) is a powerful, built-in solution that provides robust text search capabilities directly within the database. Unlike external search engines, PostgreSQL FTS eliminates the need for separate infrastructure and ensures that your search results are always up to date with minimal overhead. By leveraging key features like `tsvector`, `tsquery`, and various ranking functions, users can perform highly efficient, linguistically-aware searches on their data.

From parsing and indexing to complex query handling and ranking, PostgreSQL provides a comprehensive, flexible system for managing and querying text data. With its ability to handle linguistic variations, rank results, and support customizable configurations for different languages, PostgreSQL’s FTS makes it an ideal choice for anyone looking to build an integrated and scalable search solution without relying on external search engines.

In summary, PostgreSQL's Full Text Search offers everything you need for sophisticated search functionalities, whether you're building a simple search feature or tackling complex, high-performance search use cases. The deep integration into the database ensures consistency, performance, and real-time results, making it a powerful tool for developers and database administrators alike — without reaching for external tools.



#### Resources 
https://pgconf.in/files/presentations/2020/Oleg_Bartunov_2020_Full_Text_Search.pdf

pg docs link

