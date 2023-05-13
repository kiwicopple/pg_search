# Supabase Search

A Postgres extension for searching:

- Full text search: for standard search capabilities
- Vector search: for similarity search
- Autocomplete (TBD)

When a user performs a query their query is stored in a `queries` table for analysis and retrieval.

## Getting started

```sql
-- Coming soon
select dbdev.install('supabase-search')
```

## Search API 

The search functions are the most important.

**Text search**

Text search works like a regular search (similar to Google). 

```js
const { data } = supabase.rpc('text_search', {
    query: 'some query string',
    rows: 10 // defaults to 10 results returned at a time
})
```

**Semantic search**

Semantic search works is useful for similarity search.

```js
const { data } = supabase.rpc('text_search', {
    query: 'some query string',
    rows: 10, // defaults to 10 results returned at a time
    threshold: 0.7 // the similarity threshold. Higher is more similar
})
```
## Storage API

**Concepts**

There are 2 important concepts: 

1. *Documents*: chunks of searchable content.
2. *Context*: where the content comes from, usually a webpage.

Imagine you have a website with the following pages and sections

- `developer.mozilla.org/intro` <- *Context*
  - "What is MDN?" <- *Document*
  - "How to use it?" <- *Document*
- `developer.mozilla.org/getting-started` <- *Context*
  - "Installing important tools" <- *Document*
  - "Updating your toole" <- *Document*


Each section is a `document`. Every document belongs to some `context`. Storing sections into separate rows makes the search functionality more accurate and faster.


**Context API**

Before uploading your `documents`, you probably want to save the `context`. This isn't required, but it's useful for building search interfaces. The `context` is stored as a checksum. It's expensive to re-index your content often, so if the checksum hasn't changed then you can skip any updates for the `documents`.

```js
const { data, status } = await supabase.rpc('upsert_context', {
    // An ID that you can re-use in the future:
    id: 'developer.mozilla.org/intro', 
    // The content which we want to checksum:
    content: '# Intro \n Welcome to MDN.',
    // Some meta data, which might be useful in a search interface:
    meta: { source: 'docs', url: 'https://developer.mozilla.org/intro' },
})

// status == 201: if the context is new
// status == 200: if the context is updated
// status == 234: if there has been no change since last time
```

You can verify a checksum on any content without upserting the context using `content_checksum()`:

```js
const { data: checksum } = await supabase.rpc('content_checksum', {
    content: '# Intro \n\n Welcome to MDN.',
})
```


**Documents API**

When you update 

```js
const docs = [
    {
        context_id: 'developer.mozilla.org/intro',
        context_version: 'some-uuid',
        content: '## What is MDN? \n\n MDN is where developers learn.',
        meta: { url: 'https://developer.mozilla.org/intro#what', tags: ['guides'] },
    },
    {
        context_id: 'developer.mozilla.org/intro',
        context_version: 'some-uuid',
        content: '## How to use it? \n\n Read it, search it, start building.',
        meta: { url: 'https://developer.mozilla.org/intro#how', tags: ['guides'] },
    },
]

supabase.rpc('update_documents')

```




— this should be chunked up documents. 
— If you want it to be smaller
table documents (
  id serial primary key,
  context_id foreign key context on delete cascade, — optional
  updated_at,
  content text,
  meta jsonb, — store the section slug, page slug, etc
  checksum,
  fts text search,  — indexed
  autocomplete trigrams — indexed
  embedding vector()
);