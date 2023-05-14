
create table context ( 
  "id" text primary key, -- natural key - can be a URL, a document id, etc. User to provide.
  "updated_at" timestamp with time zone default timezone('utc'::text, now()) not null,
  "checksum" text, -- the checksum of the content so that a developer can check if the content has changed
  "meta" jsonb -- can store things like "type" or "path"
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


-- Creates a SQL function "upsert_context()" that takes an id, content, and meta and upserts the context table.
-- If the content has changed, it will update the checksum and updated_at.
-- If the content has not changed, it return a 304 (Not Modified).
create or replace function upsert_context(
    id text, 
    content text, 
    meta jsonb
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
    where context.id = upsert_context.id 
    limit 1;

    -- if there is no existing row, insert and return 201 (Created)
    if existing is null then
        insert into context (id, checksum, meta)
        values (id, new_checksum, meta)
        returning * into new_row;
        perform set_config('response.status', '201', true);
        return new_row;
    end if;

    -- if the checksum is the same, return 234 (Not Modified)
    if existing.checksum = new_checksum then
        perform set_config('response.status', '234', true);
        return existing;
    end if;

    -- if the checksum is different, update the checksum and return 200 (OK)
    update context
    set 
        checksum = new_checksum, 
        updated_at = timezone('utc'::text, now()), 
        meta = upsert_context.meta
    where context.id = upsert_context.id
    returning * into updated_row;
    return updated_row;
end;
$$;

