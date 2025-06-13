# Unlocking Powerful Search in PostgreSQL with Full Text Search
**Boost PostgreSQL Performance with Built-In Full Text Search for Fast, Accurate SQL Queries**

**Abstract**  
Looking to implement powerful search functionality without relying on external tools like Elasticsearch or Solr? PostgreSQL Full Text Search (FTS) offers a high-performance, fully integrated SQL search engine for natural-language text matching, advanced indexing, and relevance ranking—all inside your database. 

In this guide, we explore how to use PostgreSQL's `tsvector`, `tsquery`, language configurations, and ranking functions to build scalable, accurate, and efficient search queries. Perfect for developers and database architects building modern search-driven applications with PostgreSQL. 

Together with the PostGres `pgvector` plugin you can create semantic search and keyword search, implement hybrid search, all where your data lives, and seamlessy integrate in a Retrieval Augmented Generation (RAG) application.


## **Introduction**

While external search engines like Elasticsearch, Solr, or Sphinx are known for their speed, they come with trade-offs: they can’t always index virtual or dynamic documents, lack access to rich relational attributes, and introduce maintenance overhead for DBAs, and additional costs to run. They may also lag behind the database, showing outdated results, and often require separate infrastructure, certifications, and sync mechanisms. In contrast, PostgreSQL’s built-in FTS offers a fully integrated, transaction-safe, and consistent solution—supporting real-time indexing, rich queries, concurrency, and deep configurability, all within the database engine itself.

Searching text in SQL databases is often limited to basic pattern matching. But PostgreSQL goes far beyond `LIKE` and regex with its built-in FTS — a powerful system for identifying natural-language documents that match a query and ranking them by relevance. Whether you're indexing articles, logs, or messages, FTS in PostgreSQL offers scalable and sophisticated search capabilities right out of the box.


## Text search overview
Text search in search engines like Elasticsearch, Solr, or OpenSearch follows a multi-phase process designed to optimize retrieval, relevance, and scalability for large volumes of text. The process begins with **ingestion**, where raw text documents are processed through a pipeline that includes **tokenization, normalization, and analysis**:
- Text is first split into tokens e.g., words
- normalized: e.g. by lowercasing, removing stop words, applying stemming or lemmatization, to create terms suitable for indexing 
- These terms are stored in an inverted index, a data structure that maps each term to the documents (and positions) in which it appears, allowing fast lookup during searches.

The **search query undergoes the same analysis pipeline** to generate a comparable set of normalized terms. The engine then retrieves candidate documents from the inverted index that contain these terms and applies ranking algorithms to measure relevance — typically based on TF-IDF (term frequency–inverse document frequency), BM25, or vector similarity scores (TODO add LINKS). 

Search engines also support advanced features like fuzzy matching, synonyms, phrase queries, boosting, and faceting, as well as semantic search using embeddings or vector search.

Unlike relational databases, these **engines are optimized** for full-text search at scale, distributed querying, and near real-time indexing. They maintain dedicated infrastructure, offer schema flexibility (especially Elasticsearch’s document-based JSON format), and are often decoupled from transactional consistency concerns, **trading some ACID guarantees for speed and scalability**. This architecture makes them ideal for applications like log analytics, e-commerce product search, or intelligent document retrieval.



## **Why Full Text Search in PostGres?**

Traditional search methods such as `LIKE` or `~` fall short when it comes to:
* Handling linguistic variations (e.g., *satisfy* vs. *satisfies*)
* Ranking search results
* Performance with large volumes of data 

PostgreSQL’s FTS solves these with tokenization, normalization, and indexed search.

## **How PostgreSQL Handles Text Search Internally**
- **Parsing**: PostgreSQL breaks documents into **tokens** (e.g., words, numbers, emails) using a built-in parser. Custom parsers can be defined for specialized needs.

- **Normalization**: Tokens are converted into **lexemes**—standardized word forms, root forms of words—by removing suffixes, folding case, and filtering out common stop words. This step ensures similar words (like satisfy and satisfies, running and run etc) match.

- **Storage**: Documents are stored as **tsvectors** — sorted arrays of lexemes, optionally with position info to improve relevance ranking in dense query matches.


## `tsvector` and `tsquery`: Core Data Types for Full Text Search

At the heart of PostgreSQL’s full text search system are two specialized data types: `tsvector` and `tsquery`. These work together to enable fast and powerful text search capabilities.

* **`tsvector`** is used to store the *preprocessed* content of a document - normalised tokens plus stop-word removal, the lexemes - ready to be indexed and searched. Optionally, it can also store positional data to support relevance ranking or phrase matching. For example:

  ```sql
  SELECT to_tsvector('The quick brown fox jumps over the lazy dog');
  -- Outputs: 'brown':3 'dog':9 'fox':4 'jump':5 'lazi':8 'quick':2
  ```

* **`tsquery`** represents the *search condition*. It’s a structured query format that includes lexemes and logical operators (`&` for AND, `|` for OR, `!` for NOT), as well as phrase and proximity operators like `<->` (FOLLOWED BY). 
For instance, a search query might look like:
  ```sql
  SELECT to_tsquery('quick & fox');
  -- Returns a tsquery: 'quick' & 'fox'
  ```
  
You can match these types using the `@@` operator:

```sql
SELECT to_tsvector('quick brown fox') @@ to_tsquery('quick & fox');
-- Returns: true
```

Or even use the `text @@ text` form for convenience:

```sql
SELECT 'quick brown fox' @@ 'quick & fox';
-- Also returns true
```

The following variants are possible:

```sql
tsvector @@ tsquery 
tsquery  @@ tsvector
text @@ tsquery -- equivalent to to_tsvector(x) @@ y
text @@ text -- equivalent to to_tsvector(x) @@ plainto_tsquery(y)
```


Use **phrase matching** with the  `<-> (FOLLOWED BY)` tsquery operator:

```sql
SELECT to_tsvector('text search') @@ to_tsquery('text <-> search');
-- returns true
```


```sql
SELECT to_tsvector('text search') @@ to_tsquery('search <-> text');
-- returns false
```

By converting documents to `tsvector` and search terms to `tsquery`, PostgreSQL enables highly efficient and linguistically aware search, making it suitable for everything from simple keyword matching to complex, ranked document retrieval.


## Configurations: Language-Aware Search

PostgreSQL includes **text search configurations** for many languages, which control how text is parsed and normalized. A configuration consists of:

* A **parser** to break text into tokens.
* One or more **dictionaries** to normalize or eliminate tokens (e.g., stemming, stop-word filtering).

You can check available configurations with the `psql` command `\dF`.

# ---- COMMENT: would be useful to include its output ----

And specify one explicitly:

```sql
SELECT to_tsvector('french', 'les chats aiment le lait');
```

Or set a default for your session or database:

```sql
SET default_text_search_config = 'english';
```

Custom configurations can also be created if you need tailored parsing or synonym handling. This makes PostgreSQL full text search flexible and adaptable to multilingual or domain-specific use cases.


## Indexing

PostgreSQL allows full text search even without an index, making it easy to try out queries before optimizing them. For example, the following query finds rows where the `body` column includes any variant of the word *friend*, such as *friends* or *friendly*:

```sql
SELECT title
FROM pgweb
WHERE to_tsvector('english', body) @@ to_tsquery('english', 'friend');
```

You can omit the configuration name ('english' above) if the system default is acceptable:

```sql
SELECT title
FROM pgweb
WHERE to_tsvector(body) @@ to_tsquery('friend');
```

For more complex searches, you can combine fields:

```sql
SELECT title
FROM pgweb
WHERE to_tsvector(title || ' ' || body) @@ to_tsquery('create & table')
ORDER BY last_mod_date DESC
LIMIT 10;
```

While these queries work, they’re inefficient for frequent use. To improve performance, create a GIN index (see below for explanation):


```sql
CREATE INDEX pgweb_idx ON pgweb USING GIN (to_tsvector('english', body));
```

Be sure to match the configuration in your query to the one used in the index. For multilingual datasets, you can store the configuration in a column:

```sql
CREATE INDEX pgweb_idx ON pgweb USING GIN (to_tsvector(config_name, body));
```

You can also create indexes over multiple fields:

```sql
CREATE INDEX pgweb_idx ON pgweb USING GIN (to_tsvector('english', title || ' ' || body));
```

For better performance and simpler queries, consider adding a generated `tsvector` column:

```sql
ALTER TABLE pgweb
ADD COLUMN textsearchable_index_col tsvector
GENERATED ALWAYS AS (
  to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
) STORED;

CREATE INDEX textsearch_idx ON pgweb USING GIN (textsearchable_index_col);
```

This approach reduces query complexity and avoids recomputing `to_tsvector()` at search time, making it ideal for high-performance applications.

### The GIN index
PostgreSQL’s **GIN (Generalized Inverted Index)** is a specialized index type designed to efficiently support containment queries on composite data types — particularly well-suited for full text search (and json data). In the context of `tsvector` columns used for full text indexing, GIN indexes store a mapping from each lexeme to the list of documents (or rows) in which it appears, much like an inverted index in traditional search engines. 

This allows PostgreSQL to quickly locate documents matching a search term without scanning the entire table. GIN indexes are highly effective for queries involving `@@` operators, which match `tsquery` conditions against a `tsvector`. While GIN indexes are slower to build and update than B-tree indexes, they offer excellent query performance, especially for read-heavy applications with large text datasets.



## Core Functions for Full Text Search in PostgreSQL

PostgreSQL offers a comprehensive toolkit for implementing FTS, from parsing documents to interpreting user queries. Below are the core functions involved, each serving a unique role in the search workflow.

### `to_tsvector`: Parsing Documents

`to_tsvector` transforms raw document text into a normalized `tsvector`.

**Example:**
```sql
SELECT to_tsvector('english', 'A fat cat sat on a mat - it ate fat rats');
-- 'ate':9 'cat':3 'fat':2,11 'mat':7 'rat':12 'sat':4
```

Notice how:

* Stop words like "a", "on", and "it" are removed.
* Plural forms like "rats" are reduced to their singular form "rat".
* Punctuation is ignored.

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

