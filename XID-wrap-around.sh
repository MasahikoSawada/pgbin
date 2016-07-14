#!/bin/sh

source ${PGBINPATH}/common.sh

PGPORT=5432
DATA=data
PPSQL="${PSQL} -d postgres"
CONF=${DATA}/postgresql.conf
LOGFILE="xid-wrap.log"

# clean up
if [ -e "${DATA}/postmaster.pid" ]; then
    bin/pg_ctl stop -D ${DATA} -mi > /dev/null
    echo "server stopped"
fi
rm -rf ${DATA}
rm -f ${LOGFILE}

# initialize server
bin/initdb -D ${DATA} -E UTF8 --no-locale > /dev/null
echo "initdb done"

#set up the server
cat <<EOF >> ${CONF}
log_autovacuum_min_duration = 0
log_line_prefix = '[%t]'
autovacuum_freeze_max_age = 100000000
autovacuum_multixact_freeze_max_age = 100000000
vacuum_freeze_table_age =  50000000
vacuum_multixact_freeze_table_age =  5000000
EOF

bin/pg_ctl start -D ${DATA} -w > /dev/null
echo "server started"


${PPSQL} -c "create table readonly (col text)"
${PPSQL} -c "create table readwrite (col text)"
${PPSQL} -f ${PGBINPATH}/sql/generate_string.sql
${PPSQL} -c "insert into readonly select generate_string(2100, 10);"
${PPSQL} -c "insert into readwrite select generate_string(2100, 10);"
${PPSQL} -c "alter table readonly set read only"

# show information
echo "infromation : before"
${PPSQL} -c "selecT oid, relname, relreadonly  from  pg_class where oid = 'readonly'::regclass or oid = 'readwrite'::regclass or relname = 'pg_toast_' || 'readonly'::regclass::oid or relname = 'pg_toast_' || 'readwrite'::regclass::oid;"

# stop server to reset xlog location
bin/pg_ctl stop -D ${DATA} -w > /dev/null

# reset xlog location
bin/pg_resetxlog -x 0x20000000 ${DATA}

# start server again
bin/pg_ctl start -D ${DATA} -w -l ${LOGFILE} > /dev/null
echo "server started again"

${PPSQL} -c "select txid_current()"
echo "Done. Please see also ${LOGFILE}"



