create or replace function is_singleton()
	returns bool
	language sql
as $$
	/* Checks if the current process is the only process
	with that query
	If no other processes are excuting the same query, returns true
	otherwise, false
	
	useful for background workers to make sure only one instance is running at a time.
	*/
	select
		count(1) = 1
	from 
		pg_stat_activity
	where
		query = (select query from pg_stat_activity where pid = pg_backend_pid())
$$;


create or replace function worker()
	returns void
	language plpgsql
as $$
declare
	working_task embedding_api_queue;
	in_flight_resp net.http_response_result;
	working_emb double precision[];
	n_in_flight_tasks int;
    max_in_flight int := 50;
begin
	if not is_singleton() then
		raise notice 'Another instance of the worker is running';
		return;
	end if;

	-- Submit work if not too much in flight
	n_in_flight_tasks := count(*) from embedding_api_queue where task_state = 'IN-FLIGHT';
	
	if n_in_flight_tasks < max_in_flight then
		for working_task in (
			select *
			from embedding_api_queue ta
			where
				task_state in ('NOT_STARTED', 'PENDING_RETRY')
            limit
                max_in_flight - n_in_flight_tasks
		)
			loop

            update embedding_api_queue
                set task_state = 'IN-FLIGHT',
				submit_at = now(),
                submit_id = net.http_post(
                    url := 'https://api.openai.com/v1/embeddings',
                    body := jsonb_build_object(
                        'input', (
                            select 
                                s.content
                            from
                                span s
                            where
                                s.id = (working_task).span_id
                        ),
                        'model', 'text-embedding-ada-002'
                    ),
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'Authorization', 'Bearer ' || (
                            select value from api_key where key='OPENAI'
                        ) 
                    ),
                    timeout_milliseconds := 45000
                )
			where
				id = (working_task).id;

		end loop;
			
	end if;

	
	-- Update status of any IN-FLIGHT tasks
	for working_task in (
		select *
		from embedding_api_queue ta
		where
			task_state = 'IN-FLIGHT'
			-- Has either completed or failed by 30 seconds
			and submit_at < (now() - '5 seconds'::interval)
		)
		loop
		
		in_flight_resp := (
			select net._http_collect_response(request_id:=(working_task).submit_id)
		);
		
		if in_flight_resp.status <> 'SUCCESS' then

			if working_task.collect_attempt <= 5 then
				update embedding_api_queue
					set collect_attempt = collect_attempt + 1
					where id = (working_task).id;
			else
				-- pg_net issue
				update embedding_api_queue
					set task_state = 'ERROR'
					where id = (working_task).id;
			end if;
		else
			if ((in_flight_resp).response).status_code <> 200 then
				if (working_task).submit_attempt < 3 then
					update embedding_api_queue
						set task_state = 'PENDING_RETRY',
						server_resp = to_json(in_flight_resp),
						submit_attempt = submit_attempt + 1
						where id = (working_task).id;
				else 
					update embedding_api_queue
						set task_state = 'ERROR',
						server_resp = to_json(in_flight_resp),
						submit_attempt = submit_attempt + 1
						where id = (working_task).id;
				end if;
			else
                -- Move the embedding to the span table
                update span
                    -- Dimension or bad output error possible here
                    set embedding = (
                        (((in_flight_resp).response).body).json
                        -> 'data'
                        -> 0
                        ->> 'embedding'
					-- vector doesn't parse whitespace well
                    )::jsonb::text::vector(1536)
                    where id = (working_task).span_id;
                
                -- Delete the task
                delete from embedding_api_queue
                    where id = (working_task).id;
					
			end if;
		end if;
					
	end loop;
	
	
	
	return;
end;
$$;
