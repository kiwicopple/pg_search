-- create a query function that takes a query and returns the documents, saving the query to the search_query table
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
  new_row search_query%rowtype;
begin
    insert into search_query (query) 
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
        where
            fts @@ plainto_tsquery(query);
end;
$$;
