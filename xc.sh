#!/bin/sh

. pgbin/common.sh
. pgbin/xc_function.sh


show_environment

# check argument
if [ "$#" -ne 2 -r "$#" -ne 4 ]; then
    echo "# of argument should be 2"
    exit 1
fi

NUM_COOR=$1
NUM_DATA=$2

if [ "$3" == "manage" -a "$4" != "" ]; then
    action=$4
    manage $action
    exit
fi

info "building 1 parent server and $NUM_SHARD shard"

# clean up
info "stop all servers"
manage stop
info "clean up all servers"
cleanup

# initialize
info "Initialize gtm server"
$PGBIN/initgtm -Z gtm -D $DATA_GTM

info "Initialize data node server"
for i in `seq 1 $NUM_DATA`
do
    PGDATA_DATA=$PGHOME/${DATA_DATA}${i}
    PGCONF_DATA=${PGDATA_DATA}/postgresql.conf
    PORT_DATA=`expr $PORT_DATA_BASE + $i`
    NODE_NAME=$DATA_DATA$i

    $PGBIN/initdb -D ${PGDATA_DATA} --nodename $NODE_NAME -E UTF8 --no-locale
    cat <<EOF >> ${PGCONF_DATA}
port = ${PORT_DATA}
EOF
done

info "Initialize coordinator node server"
for i in `seq 1 $NUM_COOR`
do
    PGDATA_COOR=$PGHOME/${DATA_COOR}${i}
    PGCONF_COOR=${PGDATA_COOR}/postgresql.conf
    PORT_COOR=`expr $PORT_COOR_BASE + $i`
    POOLER_PORT=`expr $PORT_COOR + 500`
    NODE_NAME=$DATA_COOR$i

    $PGBIN/initdb -D ${PGDATA_COOR} --nodename $NODE_NAME -E UTF8 --no-locale
cat <<EOF >> ${PGCONF_COOR}
port = ${PORT_COOR}
pooler_port = ${POOLER_PORT}
EOF
done

info "Launch all servers"
manage start

for i in `seq 1 $NUM_COOR`
do
    PORT_COOR=`expr $PORT_COOR_BASE + $i`
    PPSQL="$PGBIN/psql -d postgres -p $PORT_COOR"

    # Register data node
    for j in `seq 1 $NUM_DATA`
    do
	PORT_DATA=`expr $PORT_DATA_BASE + $j`
	NODE_DATA=$DATA_DATA$j
	$PPSQL -c "create node $NODE_DATA with (type = 'datanode', port = $PORT_DATA);" 
    done

    # Register coorinator node
    for j in `seq 1 $NUM_COOR`
    do
	if [ $i == $j ];then
	    continue
	fi

	PORT_COOR2=`expr $PORT_COOR_BASE + $j`
	NODE_COOR=$DATA_COOR$j
	
	$PPSQL -c "create node $NODE_COOR with(type = 'coordinator', port = $PORT_COOR2);"
    done
done
	 
