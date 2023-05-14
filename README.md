# Supabase Search

A Postgres extension for searching:

- Full text search: regular text search using Postgres Full Text Search.
- Semantic search: similarity search using pgvector
- Autocomplete (TBD): a list of terms that is preloaded into your app for autocomplete. Uses pgtrgm.

When a user performs a query their query is stored in a `queries` table for analysis and retrieval.

## Getting started

```sql
-- Coming soon
select dbdev.install('supabase-search');
```

## Concepts

There are 2 important concepts: 

1. *Documents*: chunks of searchable content.
2. *Context*: stores important context about the documents, usually webpage information. 

Imagine you have a website with the following pages and sections

- `developer.mozilla.org/intro` <- *Context*
  - "What is MDN?" <- *Document*
  - "How to use it?" <- *Document*
- `developer.mozilla.org/getting-started` <- *Context*
  - "Installing important tools" <- *Document*
  - "Updating your toole" <- *Document*


In this example, each section within the webpage is a `document`, and every document belongs to some `context` (the webpage). Storing sections in separate rows makes the search functionality more accurate and faster.
## Usage: Search 

The search functions retrieve relevant documents.

#### **Text search**

Text search works like a regular search (similar to Google). 

```js
const { data } = supabase.rpc('text_search', {
    query: 'some query string',
    rows: 10 // defaults to 10 results returned at a time
})
```

#### **Semantic search**

Semantic search works is useful for similarity search.

```js
const { data } = supabase.rpc('similarity_search', {
    query: 'some query string',
    rows: 10, // defaults to 10 results returned at a time
    threshold: 0.7 // the similarity threshold. Higher is more similar
})
```

Every search query is stored in a table and can be analyzed later to improve performance.

## Usage: Storing & Indexing Documents

Checksums are used to verify when content has changed. It's expensive to re-index your content often, so if the checksum hasn't changed then you can skip any updates.

```js
const url = 'developer.mozilla.org/intro'
const markdown = `
# Intro 

Welcome to MDN.

## What is MDN?

MDN is where developers learn

## How to use it? 

Read it, search it, start building
`

// Check if the content has changed.
const isIndexed = await supabase.rpc('has_content_changed', {
    id: 'developer.mozilla.org/intro', // A natural identifier that you can re-use in the future.
    content: markdown
})

// Exit if the content is already indexd
if (isIndexed.status == 304) {
    return 'Already indexed.'
}

// Break our content into smaller sections
const { data: chunks } = await supabase.rpc('chunks', {
    content: markdown,
    delimiter: '## ',
})

// enrich each section with some metadata
const documents = chunks.map((chunk, i) => {
    return {
        content: chunk,
        meta: { url: `${url}#${i}` } 
    }
})

// Store and index the files
const { data, status } = await supabase.rpc('load_documents', {
    id: 'developer.mozilla.org/intro', 
    content: markdown,
    meta: { source: 'docs', url: 'https://developer.mozilla.org/intro' },
    documents
})

// status == 201: if the context is new
// status == 200: if the context is updated
// status == 234: if there has been no change since last time
```


When the documents are inserted the indexes are built in the background. This can take time.


## Chunking


We provide a very basic function for chunking up a large piece of content into smaller documents. 

```js
const { data, error } = await supabase.rpc('chunks', {
    content: someLongMarkdown,
    delimiter: '###',
})
```

For advanced use cases, we suggest you use more robust functions like Langchain's [MarkdownTextSplitter](https://js.langchain.com/docs/modules/indexes/text_splitters/examples/markdown), or [RecursiveCharacterTextSplitter](https://js.langchain.com/docs/modules/indexes/text_splitters/examples/recursive_character).



## Helpers

```js
// Get an MD5 checksum of some content
const { data, error } = await supabase.rpc('content_checksum', {
    content: '# Intro \n Welcome to MDN.'
})

// Check if the content has changed
const { data, status } = await supabase.rpc('has_context_changed', {
    // A natural identifier that you can re-use in the future:
    id: 'developer.mozilla.org/intro', 
    // The content which we want to check:
    content: '# Intro \n Welcome to MDN.'
})
```


## Todos & Questions

- Vectors
  - how do we determine the dimensions at runtime?
  - How do we run the index using supabase
- Multilingual: 
  - the tsvector is "english". Switch to pgroonga?
  - should we partition the tables by locale? I doubt we'd ever need to search japanese docs when the user is searching in english
- Loading Documents
  - Should we remove the old documents when the new docs are updated. Will this be an issue? Should we run some sort of append-only structure? This will also help us with query analytics (we can store the IDs that were returned each query, rather than the entire document in the search results).
  - TODO: each document has an `id` (uuidv4), which we can allow the developer to set the ID, and we don't need to update this document if the checksum hasn't changed.
  - How should we partition this?
- Query analytics
  - Should we store the returned docs or just an array of document IDs
  - What else do we need to store? (ratings, # docs requested, #docs returned, etc)