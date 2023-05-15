-----------------
-- Core Tables --
-----------------

-- Supported document types 
create table content_type ( 
  id text primary key
);

insert into content_type(id)
values ('markdown');


-- Stores to top-level context of a document.
create table document ( 
    id text primary key, -- natural key - can be a URL, a document id, etc. User to provide.
    updated_at timestamptz default timezone('utc'::text, now()) not null,
    content text not null, -- the content slice from document
    content_type text references content_type(id) not null, 
    -- the checksum of the id + content so that a developer can check if the content has changed
    checksum text generated always as (md5(id || content)) stored,
    meta jsonb not null default '{}' -- can store things like "type" or "path"
);

create trigger handle_updated_at before update 
  on document
  for each row execute
      procedure extensions.moddatetime(updated_at);

-- Indexes the content of the document for full-text search.
create index idx_document_meta ON document using gin (meta);

-- Index checksum
create index idx_document_checksum ON document(checksum);

-- Stores a slice from a document - small chunks of text
create table span ( 
    id uuid primary key default gen_random_uuid(), 
    updated_at timestamptz default timezone('utc'::text, now()) not null,
    document_id text not null references document(id) on delete cascade,
    content text not null, -- the content slice from document
    meta jsonb, -- store the section slug, page slug, etc
    fts tsvector generated always as (to_tsvector('english', content)) stored,
    embedding vector(1536)
);

create trigger handle_updated_at before update 
  on span 
  for each row execute
      procedure extensions.moddatetime(updated_at);


-- Indexes the content of the document for full-text search.
create index idx_span_meta ON span using gin (meta);

-- Indexes the content of the document for full-text search.
create index idx_span_document_id ON span(document_id);
