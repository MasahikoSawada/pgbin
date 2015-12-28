DROP SCHEMA readonly cascade;
CREATE SCHEMA readonly;
CREATE TABLE readonly.aaa (col text);
SELECT c.oid, c.relname || '.' || n.nspname, c.relkind, c.relreadonly, c.relfrozenxid FROM pg_class as c, pg_namespace as n WHERE c.relnamespace = n.oid and n.nspname = 'readonly' and relname = 'aaa';
INSERT INTO readonly.aaa select repeat('1234567890', 100) from generate_series(1,10000);
VACUUM FREEZE readonly.aaa;      
SELECT c.oid, c.relname || '.' || n.nspname, c.relkind, c.relreadonly, c.relfrozenxid FROM pg_class as c, pg_namespace as n WHERE c.relnamespace = n.oid and n.nspname = 'readonly' and relname = 'aaa';
\echo "SET read-only"
ALTER TABLE readonly.aaa SET READ ONLY;
SELECT c.oid, c.relname || '.' || n.nspname, c.relkind, c.relreadonly, c.relfrozenxid FROM pg_class as c, pg_namespace as n WHERE c.relnamespace = n.oid and n.nspname = 'readonly' and relname = 'aaa';
INSERT INTO readonly.aaa select 1;
UPDATE readonly.aaa SET col = 1;
DELETE FROM readonly.aaa;
\echo "SET read-write"      
ALTER TABLE readonly.aaa SET READ WRITE;
SELECT c.oid, c.relname || '.' || n.nspname, c.relkind, c.relreadonly, c.relfrozenxid FROM pg_class as c, pg_namespace as n WHERE c.relnamespace = n.oid and n.nspname = 'readonly' and relname = 'aaa';
INSERT INTO readonly.aaa select 1;
UPDATE readonly.aaa SET col = 1;
DELETE FROM readonly.aaa;



\echo "pageinspect"



