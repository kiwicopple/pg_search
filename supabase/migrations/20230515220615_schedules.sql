-- We need to upgrade to pg_cron 1.5 for sub-minute schedules.
select cron.schedule('embedding_worker', '* * * * *', 'select worker()');
