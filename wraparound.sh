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

cat <<EOF >> ${CONF}
log_autovacuum_min_duration = 0
log_line_prefix = '[%t]'
EOF

# Preparation
bin/pg_ctl start -D ${DATA} -w > /dev/null
echo "server started"

${PPSQL} -c "create extension pg_frozenmap"
${PPSQL} -c "create table hoge (col text)"
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #1 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #2 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #3 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #4 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #5 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #6 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #7 insert into blk 0
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #8 insert into blk 1
${PPSQL} -c "insert into hoge select repeat('1234567890',100)"  #9 insert into blk 1
${PPSQL} -c "vacuum freeze hoge" # Freeze 2 pages and FM bit is set
${PPSQL} -c "delete from hoge" # all tuple are deleted but FM bit is set yet
${PPSQL} -c "selecT * from fm_get_info('hoge');"

bin/pg_ctl stop -D ${DATA} -w > /dev/null
echo "server stopped"

# Modify XID
#bin/pg_resetxlog -x 0x
