PORT_MASTER=5550

DATA_MASTER="master"
DATA_STANDBY="node"

PSQL_MASTER="${PSQL} -d postgres -p ${PORT_MASTER}"
PSQL_STANDBY="${PSQL} -d postgres -p ${PORT_STANDBY}"

PGDATA_MASTER=$PGHOME/$DATA_MASTER

CONF_MASTER=${DATA_MASTER}/postgresql.conf
HBA_MASTER=${DATA_MASTER}/pg_hba.conf

function info()
{
    echo -e "\e[34m[INFO] : $*\e[m";
}

function show_enviornment()
{
    info "--- Environemnt information ---"
    info "PGHOME = $PGHOME"
    info "PGPORT = $PGPORT"
    info "PGBIN  = $PGBIN"
    info "PGDATA = $PGDATA"
    info ""
    info "PORT_MASTER  = $PORT_MASTER"
    info "DATA_MASTER  = $DATA_MASTER"
    info "DATA_STANDBY = $DATA_STANDBY"
    info "-------------------------------"
}

function manage()
{
    ACTION=$1
    TARGET=$2

    if [ "$TARGET" == "master" ];then
	if [ "$ACTION" == "start" ];then
	    $PGBIN/pg_ctl -D $PGDATA_MASTER $ACTION -w
	else
	    $PGBIN/pg_ctl -D $PGDATA_MASTER $ACTION -mf
	fi
    else
	for i in `seq 1 $NUM_STANDBY`
	do
	    PGDATA_SLAVE=$PGHOME/${DATA_STANDBY}${i}
	    if [ "$ACTION" == "start" ];then
		$PGBIN/pg_ctl -D $PGDATA_SLAVE $ACTION
	    else
		$PGBIN/pg_ctl -D $PGDATA_SLAVE $ACTION -mf
	    fi
	done
    fi
}

function cleanup()
{
    rm -rf $PGDATA_MASTER $DATA_STANDBY*
}