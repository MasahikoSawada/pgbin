\echo "page inspect"
drop extension pageinspect;
create extension pageinspect;
drop schema readonly cascade;
create schema readonly;
create table readonly.bbb (col text);

CREATE OR REPLACE FUNCTION generate_string(int, int) RETURNS text AS $$
SELECT array_to_string(ARRAY(SELECT chr((97 + random() * 10) :: integer) FROM generate_series(1,($1 + random()*$2)::int)), '');
$$
LANGUAGE sql;
insert into readonly.bbb select generate_string(3000, 10);
insert into readonly.bbb select 'hoge';       
select oid, relname, relfrozenxid, relreadonly from pg_class where oid = 'readonly.bbb'::regclass or relname = 'pg_toast_' || 'readonly.bbb'::regclass::oid;
select * from heap_page_items(get_raw_page('readonly.bbb',0));
ALTER TABLE readonly.bbb set read only;
select oid, relname, relfrozenxid, relreadonly from pg_class where oid = 'readonly.bbb'::regclass or relname = 'pg_toast_' || 'readonly.bbb'::regclass::oid;
select * from heap_page_items(get_raw_page('readonly.bbb',0));



