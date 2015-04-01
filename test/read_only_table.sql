DROP SCHEMA readonly cascade;
CREATE SCHEMA readonly;
CREATE TABLE readonly.hoge (col int);
SELECT c.oid, c.relname || '.' || n.nspname, c.relkind, c.relreadonly FROM pg_class as c, pg_namespace as n WHERE c.relnamespace = n.oid and n.nspname = 'readonly' and relname = 'hoge';
ALTER TABLE readonly.hoge SET READ ONLY;
SELECT c.oid, c.relname || '.' || n.nspname, c.relkind, c.relreadonly FROM pg_class as c, pg_namespace as n WHERE c.relnamespace = n.oid and n.nspname = 'readonly' and relname = 'hoge';



