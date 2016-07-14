PORT_PRIMARY=4440

DATA_PRIMARY="pri"
DATA_SHARD="shd"

PSQL_PRIMARY="$PSQL -d postgre -p $PORT_PRIMARY"
CONF_PRIMARY=${DATA_PRIMARY}/postgresql.conf

function info()
{
    echo -e "\e[34m[INFO] : $*\e[m";
}

function show_environment()
{
    info "--- Environemnt information ---"
    info "PGHOME = $PGHOME"
    info "PGPORT = $PGPORT"
    info "PGBIN  = $PGBIN"
    info "PGDATA = $PGDATA"
    info ""
    info "PORT_PRIMARY  = $PORT_PRIMARY"
    info "DATA_PRIMARY  = $DATA_PRIMARY"
    info "-------------------------------"

}

function manage()
{
    ACTION=$1

    if [ "$ACTION" == "start" ];then
        $PGBIN/pg_ctl -D $DATA_PRIMARY $ACTION -w
    else
        $PGBIN/pg_ctl -D $DATA_PRIMARY $ACTION -mf
    fi

    for i in `seq 1 $NUM_SHARD`
    do
        PGDATA_SHARD=$PGHOME/${DATA_SHARD}${i}
        if [ "$ACTION" == "start" ];then
            $PGBIN/pg_ctl -D $PGDATA_SHARD $ACTION -w
        else
            $PGBIN/pg_ctl -D $PGDATA_SHARD $ACTION -mf
        fi
    done
}

function cleanup()
{
    rm -rf $DATA_PRIMARY $DATA_SHARD*
}
