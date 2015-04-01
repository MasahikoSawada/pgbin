#!/bin/sh

source ${PGBINPATH}/common.sh

if [ "$#" -ne 1 ];then
    echo "Should be specified 1 SQL file at least"
    exit 1
fi

# Execute SQL file
echo "Exec ${1} file.."
${PSQL} -f $1