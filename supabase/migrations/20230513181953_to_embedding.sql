create function to_embedding(text)
	returns vector(1536)
	language plpgsql
	immutable
	strict
as $$
declare
	resp extensions.http_response := extensions.http((
		'POST',
		'https://api.openai.com/v1/embeddings',
		ARRAY[
			--extensions.http_header('Content-Type', 'application/json'),
			extensions.http_header('Authorization', (
				'Bearer ' || (select value from api_key where key='OPENAI')
			))
		],
        'application/json',
		jsonb_build_object(
			'input', $1,
			'model', 'text-embedding-ada-002'
		)
	)::extensions.http_request);
		
begin
	if (resp).status = 200 then
		return (
			(resp).content::jsonb
			-> 'data'
			-> 0
			->> 'embedding'
		)::vector(1536);
	end if;

	perform raise_exception('Failed to call external API');

end;

$$;
