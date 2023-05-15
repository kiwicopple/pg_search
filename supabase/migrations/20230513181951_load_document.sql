-----------------------
-- Loading Documents --
-----------------------

-- On insert/update segment the doc
create or replace function document_to_spans()
    returns trigger
    language plpgsql
    security definer
    as $$
    begin
		delete from span
			where document_id = new.id;

        insert into span(document_id, content)
        select
			new.id, cg.t
		from
			chunk_generic(
                new.content,
                case new.content_type
                    when 'markdown' then e'\n#'
                    else raise_exception('unknown content type')
                end
            ) cg(t);

        return new;
    end;
    $$;

create or replace trigger on_new_doc_do_split
    after insert on document
    for each row execute procedure document_to_spans();


-- On insert/update segment the doc
create or replace function spans_to_api_queue()
    returns trigger
    language plpgsql
    security definer
    as $$
    begin
		insert into embedding_api_queue(span_id)
			values (new.id);

        return new;
    end;
    $$;

create or replace trigger on_new_span_do_api
    after insert on span 
    for each row execute procedure spans_to_api_queue();




-- Creates a SQL function "load_documents()" that takes an id, content, and meta and upserts the document table.
-- If the content has changed, it will update the checksum and updated_at.
-- If the content has not changed, it return a 304 (Not Modified).
create or replace function load_document(
    id text, 
    content_type text,
    content text, 
    meta jsonb
)
returns document 
language plpgsql
as $$
declare
  new_checksum text := md5(id || content);
  existing document%rowtype;
  new_row document%rowtype;
  updated_row document%rowtype;
begin
    select * into existing 
    from public.document doc
    where doc.id = $1 
    limit 1;


    -- if the checksum is the same, return 304 (Not Modified)
    if existing.checksum = new_checksum then
        perform set_config('response.status', '304', true);
        return existing;
    end if;

    -- if there is no existing row, insert and return 201 (Created)
    if existing is null then
        insert into document (id, content_type, content, meta)
        values (id, content_type, content, meta)
        returning * into new_row;

        perform set_config('response.status', '201', true);
        return new_row;
    end if;

    -- if the checksum is different, delete spans and update document
    perform set_config('response.status', '200', true);

    delete from span where id = load_document.id;

    update document
    set
        content = $2,
        content_type = $3,
        meta = $4
    returning * into updated_row;

    return updated_row;
end;
$$;



