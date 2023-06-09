-- create a query function that takes a query and returns the documents, saving the query to the search_query table
create or replace function search_by_text(
	query text,
	top_k smallint default 15,
	filters jsonb = '{}'
 )
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
  new_row search_query%rowtype;
begin
    insert into search_query (query, search_method) 
    values ($1, 'FULL TEXT')
    returning * into new_row;
    
    return query
        select 
            span.id,
            span.meta,
            span.content,
            span.document_id,
            document.meta,
            new_row.id as query_id
        from 
            span
        	join document 
        	on span.document_id = document.id
        where
			fts @@ plainto_tsquery(query)
			and case
				when filters is null then true
				when filters = '{}' then true
				else span.meta @> filters
			end
		order by
			ts_rank(fts, plainto_tsquery(query))
		limit
			top_k;
end;
$$;


create or replace function search_by_embedding(
	query vector(1536),
	top_k smallint default 15,
	filters jsonb = '{}'
 )
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
  new_row search_query%rowtype;
begin
    insert into search_query (query, search_method) 
    values ($1, 'EMBEDDING TEXT')
    returning * into new_row;
    
    return query
        select 
            span.id,
            span.meta,
            span.content,
            span.document_id,
            document.meta,
            new_row.id as query_id
        from 
            span
        	join document 
        	on span.document_id = document.id
        where
        	case
				when filters is null then true
				when filters = '{}' then true
				else span.meta @> filters
			end
		order by
			span.embedding <=> query
		limit
			top_k;
end;
$$;



