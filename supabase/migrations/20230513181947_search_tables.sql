-------------------
-- Search Tables --
-------------------

-- create an unlogged table to store all the queries that we receive
create unlogged table search_query (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default timezone('utc'::text, now()) not null,
  query text not null,
  user_id text, --optional
  feedback jsonb
);
