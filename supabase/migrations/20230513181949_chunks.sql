----------------------
-- Content Chunking --
----------------------

-- Splits any text into chunks based on a delimiter using the regexp_spit_to_table() function.
-- Includes the delimiter in the result.
-- Delimiter should NOT be a regex pattern, it should be an exact string.
create or replace function chunk_generic(content text, delimiter text)
    returns setof text
    language plpgsql stable
as $$
declare
	segment text;
	used_segs text := '';
	ix int;
begin
  -- Inject a custom delimiter before each match, because the regex will remove the delimiter
  content := replace(content, delimiter, '{SPLIT_CHUNK}' || delimiter);

  -- Split by the delimiter
  return query 
  with split as ( select regexp_split_to_table(content, '{SPLIT_CHUNK}') as chunk )
  select * from split where chunk <> '';
end;
$$;


