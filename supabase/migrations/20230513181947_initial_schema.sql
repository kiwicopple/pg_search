create extension if not exists vector;

-- Stores to top-level document of a span.
create table document ( 
  "id" text primary key, -- natural key - can be a URL, a span id, etc. User to provide.
  "updated_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "checksum" text, -- the checksum of the content so that a developer can check if the content has changed
  "meta" jsonb -- can store things like "type" or "path"
);

-- Stores the content of a span - small chunks of text
create table spans ( 
  "id" uuid primary key default uuid_generate_v4(), 
  "updated_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "document_id" text references "document" not null,
  "content" text not null, -- the content of the span
  "meta" jsonb, -- store the section slug, page slug, etc
  "fts" tsvector generated always as (to_tsvector('english', content)) stored
);

-- Indexes the content of the span for full-text search.
create index idx_span_fts ON spans using gin (fts);

-- create an unlogged table to store all the queries that we receive
create unlogged table queries (
  "id" uuid primary key default uuid_generate_v4(),
  "created_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "query" text not null,
  "user_id" text, --optional
  "feedback" jsonb
);

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

-- Creates a SQL function "load_documents()" that takes an id, content, and meta and upserts the document table.
-- If the content has changed, it will update the checksum and updated_at.
-- If the content has not changed, it return a 304 (Not Modified).
create or replace function load_documents(
    id text, 
    content text, 
    meta jsonb,
    spans jsonb
)
returns document
language plpgsql
as $$
declare
  new_checksum text;
  existing document%rowtype;
  new_row document%rowtype;
  updated_row document%rowtype;
begin
    new_checksum := content_checksum(content);

    select * into existing 
    from document 
    where document.id = load_documents.id 
    limit 1;

    -- if the checksum is the same, return 234 (Not Modified)
    if existing.checksum = new_checksum then
        perform set_config('response.status', '234', true);
        return existing;
    end if;

    -- if there is no existing row, insert and return 201 (Created)
    if existing is null then
        insert into document (id, checksum, meta)
        values (id, new_checksum, meta)
        returning * into new_row;

        insert into spans (document_id, content, meta)
        select load_documents.id, elem->'content', elem->'meta'
        from jsonb_array_elements(to_jsonb(spans)) AS elem;

        perform set_config('response.status', '201', true);
        return new_row;
    end if;


    -- if the checksum is different, update the spans and return 200 (OK)
    update document
    set 
        checksum = new_checksum, 
        updated_at = timezone('utc'::text, now()), 
        meta = load_documents.meta
    where document.id = load_documents.id
    returning * into updated_row;

    delete from spans where document_id = load_documents.id;

    insert into spans (document_id, content, meta)
    select id, elem->'content', elem->'meta'
    from jsonb_array_elements(to_jsonb(spans)) AS elem;
    
    return updated_row;
end;
$$;

-- create a query function that takes a query and returns the spans, saving the query to the queries table
create or replace function text_search(query text)
returns table(
    span_id uuid, 
    span_meta jsonb, 
    content text, 
    document_id text, 
    document_meta jsonb, 
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
        spans.id as span_id,
        spans.meta as span_meta,
        spans.content,
        spans.document_id,
        document.meta as document_meta,
        new_row.id as query_id
    from 
        spans 
    join 
        document 
    on 
        spans.document_id = document.id
    where fts @@ plainto_tsquery(query);
end;
$$;
