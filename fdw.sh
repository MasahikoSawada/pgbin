#!/bin/sh

. pgbin/common.sh
. pgbin/fdw_function.sh

show_environment

# check argument
if [ "$#" -ne 1 ]; then
    echo "# of argument should be 1"
    exit 1
fi

NUM_SHARD=$1

info "building 1 parent server and $NUM_SHARD shard"

# clean up
info "stop all servers"
manage stop
info "clean up all servers"
cleanup

# initialize
info "Initialize primary server"
$PGBIN/initdb -D $DATA_PRIMARY -E UTF8 --no-locale > /dev/null

cat <<EOF >> ${CONF_PRIMARY}
port = ${PORT_PRIMARY}
log_line_prefix = '%p'
wal_level = logical
max_wal_senders = 5
wal_keep_segments = 10
max_wal_size = 512MB
EOF

for num in `seq 1 ${NUM_SHARD}`
do
    PGDATA_SHARD=$PGHOME/$DATA_SHARD${num}
    CONF_SHARD=${PGDATA_SHARD}/postgresql.conf
    PORT_SHARD=`expr $PORT_PRIMARY + $num`

    $PGBIN/initdb -D $PGDATA_SHARD -E UTF8 --no-locale > /dev/null

    cat <<EOF >> ${CONF_SHARD}
port = ${PORT_SHARD}
log_line_prefix = '%p'
wal_level = logical
max_wal_senders = 5
wal_keep_segments = 10
max_wal_size = 512MB
EOF
done

# Start all servers
info "Launch all servers"
manage start

# Set up master with fdw
PPRIMARY="$PGBIN/psql -d postgres -p $PORT_PRIMARY"

$PPRIMARY -c "create extension postgres_fdw"
$PPRIMARY -c "create table p(col int)"

for num in `seq 1 $NUM_SHARD`
do
    PORT_SHARD=`expr $PORT_PRIMARY + $num`
    PSHARD="$PGBIN/psql -d postgres -p $PORT_SHARD"
    NUM=`expr $num - 1`
    MIN=`expr 100 \* $NUM`
    MAX=`expr $MIN + 100`

    $PPRIMARY -c "create server shard${num} foreign data wrapper postgres_fdw options (port '$PORT_SHARD', dbname'postgres');"
    $PPRIMARY -c "create foreign table s${num} (check (col >= $MIN and col < $MAX)) inherits(p) server shard${num}"
    $PPRIMARY -c "create user mapping for masahiko server shard${num}"

    $PSHARD -c "create extension postgres_fdw;"
    $PSHARD -c "create table s${num} (col int)"
    $PSHARD -c "insert into s${num} select generate_series($MIN, $MAX -1)"
done
