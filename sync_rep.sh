#!/bin/sh

. pgbin/common.sh
. pgbin/sync_rep_function.sh

show_enviornment

# check argument
if [ "$#" -ne 1 ];then
    echo "Argument should be 1"
    exit 1
fi
NUM_STANDBY=$1
info "bulding 1 master server and $NUM_STANDBY standby(s)"

# clean up
info "stop all servers"
manage stop slave
manage stop master

info "clean up all servers"
cleanup

# initialize both server
info "initializing master server"
$PGBIN/initdb -D ${DATA_MASTER} -E UTF8 --no-locale > /dev/null

# set up the master
cat <<EOF >> ${CONF_MASTER}
port = ${PORT_MASTER}
wal_level = hot_standby
max_wal_senders = 5
wal_keep_segments = 10
max_wal_size = 128MB
wal_log_hints = on
wal_sender_timeout = 0
wal_receiver_timeout = 0
EOF

cat <<EOF >> ${HBA_MASTER}
local   replication     masahiko                                trust
EOF

info "lanch master server"
manage start master

# set up the standby
info "initializing standby server(s)"
for num in `seq 1 ${NUM_STANDBY}`
do
    PGDATA_STANDBY=$PGHOME/$DATA_STANDBY${num}
    CONF_STANDBY=${PGDATA_STANDBY}/postgresql.conf
    RECOV_STANDBY=${PGDATA_STANDBY}/recovery.conf
    PORT_STANDBY=`expr $PORT_MASTER + $num`

    $PGBIN/pg_basebackup -P -p ${PORT_MASTER} -D ${PGDATA_STANDBY} -x

    cat <<EOF >> ${CONF_STANDBY}
port = ${PORT_STANDBY}
EOF

    cat <<EOF >> ${RECOV_STANDBY}
standby_mode = on
primary_conninfo = 'port=${PORT_MASTER} application_name=$DATA_STANDBY$num'
EOF
done

info "lanch all standby server(s)"
manage start slave

exit 0

###########################################################################################
echo "Press to insert master"
read FOO

# set data to master
${PSQL_MASTER} -c "create table hoge (col text);"
${PSQL_MASTER} -c "insert into hoge values ('master, before promote, before checkpoint')"
${PSQL_MASTER} -c "checkpoint;"

walsenderpid=$(ps uax | grep "wal sender" | grep -v grep | awk '{ print $2 }')
kill -19 ${walsenderpid}

${PSQL_MASTER} -c "insert into hoge values ('master, before promote, this data is not in standby')"
${PSQL_MASTER} -c "select * from hoge"

echo "Press to promote master"
read FOO
if [ "${FOO}" == "e" ];then
   exit 0
fi
sleep 1

# promote standby
bin/pg_ctl promote -D ${DATA_STANDBY}
sleep 3
${PSQL_STANDBY} -c "insert into hoge values('standby, after promote')"

# stop both
kill -18 ${walsenderpid}
bin/pg_ctl stop -D ${DATA_MASTER} -mf > /dev/null
echo "[M] : master stoppped"
bin/pg_ctl stop -D ${DATA_STANDBY} > /dev/null
echo "[S] : standby stopped"

# pg_rewind
echo "bin/pg_rewind --target-pgdata=${DATA_MASTER} --source-pgdata=${DATA_STANDBY}"
echo "Press any key to continue.."
read FOO
cp ${CONF_MASTER} ./tmp
bin/pg_rewind --target-pgdata=${DATA_MASTER} --source-pgdata=${DATA_STANDBY}
mv ./tmp ${CONF_MASTER}

# start old master and execute query
echo "Press any key to start master"
read FOO
bin/pg_ctl start -D ${DATA_MASTER} -w
${PSQL_MASTER} -c "selecT * from hoge"
