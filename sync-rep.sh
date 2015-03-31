#!/bin/sh

source ${PGBINPATH}/common.sh

PORT_MASTER=5555
DATA_MASTER="master_data"
DATA_STANDBY="standby_data"

PSQL_MASTER="${PSQL} -d postgres -p ${PORT_MASTER}"
PSQL_STANDBY="${PSQL} -d postgres -p ${PORT_STANDBY}"

CONF_MASTER=${DATA_MASTER}/postgresql.conf
HBA_MASTER=${DATA_MASTER}/pg_hba.conf

# check argument
if [ "$#" -ne 1 ];then
    echo "Argument should be 1"
    exit 1
fi
NUM_STANDBY=$1

# clean up
if [ -e "${DATA_MASTER}/postmaster.pid" ]; then
    bin/pg_ctl stop -D ${DATA_MASTER} -mi > /dev/null
    echo "[  M  ] : master stopped"
fi
rm -rf ${DATA_MASTER}

for DIR in `ls -1 | egrep "${DATA_STANDBY}[0-9]"`
do
    if [ -e "${DIR}/postmaster.pid" ]; then
	bin/pg_ctl stop -w -D ${DIR} -mi > /dev/null
	echo "[  S  ] : standby stopped"
    fi
    echo "        :     ${DIR}"
    rm -rf ${DIR}
done

echo "[M , S] : all database cluster removed"

# initialize both server
bin/initdb -D ${DATA_MASTER} -E UTF8 --no-locale > /dev/null
echo "[  M  ] : initdb done"

# set up the master
cat <<EOF >> ${CONF_MASTER}
port = ${PORT_MASTER}
wal_level = hot_standby
max_wal_senders = 50
wal_keep_segments = 10
max_wal_size = 128MB
wal_log_hints = on
EOF

cat <<EOF >> ${HBA_MASTER}
local   replication     masahiko                                trust
EOF

bin/pg_ctl start -D ${DATA_MASTER} -w > /dev/null
echo "[  M  ] : master started"

# set up the standby
for num in `seq 1 ${NUM_STANDBY}`
do
    DIR=${DATA_STANDBY}${num}
    CONF_STANDBY=${DIR}/postgresql.conf
    RECOV_STANDBY=${DIR}/recovery.conf
    PORT_STANDBY=`expr 5555 + $num`

    bin/pg_basebackup -P -p ${PORT_MASTER} -D ${DIR} -x

    cat <<EOF >> ${CONF_STANDBY}
hot_standby = on
port = ${PORT_STANDBY}
EOF

    cat <<EOF >> ${RECOV_STANDBY}
standby_mode = on
primary_conninfo = 'port=${PORT_MASTER}'
EOF

    bin/pg_ctl start -D ${DIR} -w > /dev/null
    echo "[S : ${num}] : standby started"
done

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
