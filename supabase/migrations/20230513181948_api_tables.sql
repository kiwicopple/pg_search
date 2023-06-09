----------------------
-- Embedding Tables --
----------------------

-- TODO(use vault)
create table api_key(
    key text primary key,
    value text not null
);


create type task_state as enum (
	'NOT_STARTED',
	'PENDING_RETRY',
	'IN-FLIGHT',
	'ERROR'
);



create table embedding_api_queue(
	id bigserial primary key,
	span_id uuid not null references span(id),
	task_state task_state default 'NOT_STARTED' not null,
	
	-- requesting from server allows retries
	submit_id bigint,
	submit_attempt smallint default 0,
	submit_at timestamptz,
	
	-- collecting response allows retries
	collect_attempt smallint default 0,
	
	-- response from API server
	server_resp jsonb,

	embedding jsonb, -- length agnostic
	created_at timestamptz default timezone('utc'::text, now()) not null
);

create index ix_task_state on embedding_api_queue (task_state);
create index ix_submit_at on embedding_api_queue using brin (submit_at);
