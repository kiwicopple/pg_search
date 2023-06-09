----------------
-- Exceptions --
----------------

create or replace function raise_exception(message text)
    returns text
    language plpgsql
    as $$
begin
    raise exception using errcode='22000', message=message;
end;
$$;



