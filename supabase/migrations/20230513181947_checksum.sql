create extension if not exists vector;

-- Stores to top-level context of a document.
create table context ( 
  "id" text primary key, -- natural key - can be a URL, a document id, etc. User to provide.
  "updated_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "checksum" text, -- the checksum of the content so that a developer can check if the content has changed
  "meta" jsonb -- can store things like "type" or "path"
);

-- Stores the content of a document - small chunks of text
create table documents ( 
  "id" uuid primary key default uuid_generate_v4(), 
  "updated_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "context_id" text references "context" not null,
  "content" text not null, -- the content of the document
  "meta" jsonb, -- store the section slug, page slug, etc
  "fts" tsvector generated always as (to_tsvector('english', content)) stored
);

-- create an unlogged table to store all the queries that we receive
create unlogged table queries (
  "id" uuid primary key default uuid_generate_v4(),
  "created_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "query" text not null,
  "user_id" text, --optional
  "feedback" jsonb
);

-- Indexes the content of the document for full-text search.
create index idx_document_meta ON documents using gin (meta);

-- Returns the checksum of any text.
create or replace function content_checksum(content text)
returns text 
language plpgsql stable
as $$
begin
    return md5(content);
end;
$$;

-- Splits any text into chunks based on a delimiter using the regexp_spit_to_table() function.
-- Includes the delimiter in the result.
-- Delimiter should NOT be a regex pattern, it should be an exact string.
create or replace function chunks(content text, delimiter text)
returns setof text
language plpgsql stable
as $$
begin
  -- Inject a custom delimiter before each match, because the regex will remove the delimiter
  content := replace(content, delimiter, '{SPLIT_CHUNK}' || delimiter);

  -- Split by the delimiter
  return query 
  with split as ( select regexp_split_to_table(content, '{SPLIT_CHUNK}') as chunk )
  select * from split where chunk <> '';
end;
$$;

-- Creates a SQL function "load_documents()" that takes an id, content, and meta and upserts the context table.
-- If the content has changed, it will update the checksum and updated_at.
-- If the content has not changed, it return a 304 (Not Modified).
create or replace function load_documents(
    id text, 
    content text, 
    meta jsonb,
    documents jsonb
)
returns context
language plpgsql
as $$
declare
  new_checksum text;
  existing context%rowtype;
  new_row context%rowtype;
  updated_row context%rowtype;
begin
    new_checksum := content_checksum(content);

    select * into existing 
    from context 
    where context.id = load_documents.id 
    limit 1;

    -- if the checksum is the same, return 234 (Not Modified)
    if existing.checksum = new_checksum then
        perform set_config('response.status', '234', true);
        return existing;
    end if;

    -- if there is no existing row, insert and return 201 (Created)
    if existing is null then
        insert into context (id, checksum, meta)
        values (id, new_checksum, meta)
        returning * into new_row;

        insert into documents (context_id, content, meta)
        select load_documents.id, elem->'content', elem->'meta'
        from jsonb_array_elements(to_jsonb(documents)) AS elem;

        perform set_config('response.status', '201', true);
        return new_row;
    end if;


    -- if the checksum is different, update the documents and return 200 (OK)
    update context
    set 
        checksum = new_checksum, 
        updated_at = timezone('utc'::text, now()), 
        meta = load_documents.meta
    where context.id = load_documents.id
    returning * into updated_row;

    delete from documents where context_id = load_documents.id;

    insert into documents (context_id, content, meta)
    select id, elem->'content', elem->'meta'
    from jsonb_array_elements(to_jsonb(documents)) AS elem;
    
    return updated_row;
end;
$$;

-- create a query function that takes a query and returns the documents, saving the query to the queries table
create or replace function text_search(query text)
returns table(
    document_id uuid, 
    document_meta jsonb, 
    content text, 
    context_id text, 
    context_meta jsonb, 
    query_id uuid
)
language plpgsql
as $$
declare
  new_row queries%rowtype;
begin
    insert into queries (query) 
    values (text_search.query)
    returning * into new_row;
    
    return query
    select 
        documents.id as document_id,
        documents.meta as document_meta,
        documents.content,
        documents.context_id,
        context.meta as context_meta,
        new_row.id as query_id
    from 
        documents 
    join 
        context 
    on 
        documents.context_id = context.id
    where fts @@ plainto_tsquery(query);
end;
$$;
