PORT_COOR_BASE=6000
PORT_DATA_BASE=7000

DATA_COOR="co"
DATA_DATA="dn"
DATA_GTM="gtm"

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
    info "-------------------------------"

}

function manage()
{
    ACTION=$1

    # gtm
    if [ "$ACTION" == "start" ];then
        $PGBIN/gtm_ctl -Z gtm -D $DATA_GTM $ACTION -w
    else
        $PGBIN/gtm_ctl -Z gtm -D $DATA_GTM $ACTION -mf
    fi

    # coordinator node
    for i in `seq 1 $NUM_COOR`
    do
        PGDATA_COOR=$PGHOME/${DATA_COOR}${i}
        if [ "$ACTION" == "start" ];then
            $PGBIN/pg_ctl -Z "coordinator" -D $PGDATA_COOR $ACTION -w
        else
            $PGBIN/pg_ctl -Z "coordinator" -D $PGDATA_COOR $ACTION -mf
        fi
    done

    # data node
    for i in `seq 1 $NUM_DATA`
    do
        PGDATA_DATA=$PGHOME/${DATA_DATA}${i}
        if [ "$ACTION" == "start" ];then
            $PGBIN/pg_ctl -Z "datanode" -D $PGDATA_DATA $ACTION -w
        else
            $PGBIN/pg_ctl -Z "datanode" -D $PGDATA_DATA $ACTION -mf
        fi
    done

}

function cleanup()
{
    rm -rf $DATA_COOR* $DATA_DATA* $DATA_GTM
}
