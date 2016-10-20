#!/bin/sh

######################################################################
#
# Test suite script for PostgreSQL.
#
# This tool mainly does benchmark test with configuration specified
# by $1 file while collecting resource usage using by dstat and
# r_monitor.
#
# Usage:
# $ ./pgtest.sh case.txt
#
# You can specify muliple sets of configuration parameter to test
# case file as follows.
# ----
# $ cat case.txt
# work_mem = 4MB
# shared_buffers = 1GB
# @@@
# work_mem = 4MB
# shared_buffers = 2GB
# @@@
# ---
# The string '@@@' means to run pgbench at that point. For example,
# the pgtest will run pgbench two times with the above file.
######################################################################

PGBENCH_INIT="pgbench -i -s 300 -p 5960 postgres"
PGBENCH="pgbench -M prepared -T 300 -c 4 -n -P 1 -p 5960 -l postgres"
R_MONITOR="ruby /home/masahiko/ruby/source/r_monitor/r_monitor.rb"
R_PGBENCH="ruby /home/masahiko/ruby/source/r_monitor/r_pgbench.rb"
DSTAT="dstat -tam"

PGHOME="/home/masahiko/pgsql/master"
PGCONF="${PGHOME}/data/postgresql.conf"
PGCONF_ORG="/tmp/postgresql.conf.org"

LOAD_FILE="load_file.sql"
SAMPLE_FILE="sample.sql"

# Save original configuration file
cp $PGCONF $PGCONF_ORG

# Do pgbench
function do_test()
{
    bin/pg_ctl restart -D data -o "-p 5960" -w

    # r_monitor
    $R_MONITOR > "test_$1_monitor.csv" &
    R_MONITOR_PID=$!

    # dstat
    dstat_file="test_$1_dstat.csv"
    rm -f $dstat_file
    $DSTAT --output "$dstat_file" > /dev/null &
    DSTAT_PID=$!

    $PGBENCH 2>&1 > /dev/null | tee "test_$1_pgbench.log"

    kill -9 $R_MONITOR_PID
    kill -9 $DSTAT_PID
}

function prepare_to_load()
{
    num=$1

    if [ "$num" == "0" ];then
	cat <<EOF > $LOAD_FILE
drop database if exists test;
create database test;
\c test
EOF
    fi
    
    # Process r_monitor log
    r_monitor_file="`pwd`/test_$1_monitor.csv"
    cat <<EOF >> $LOAD_FILE
create table r_monitor_$num(time timestamp, seqno int, dirty bigint, writeback bigint);
copy r_monitor_$num from '$r_monitor_file' (format csv, header on);
EOF

    # Process dstat log
    dstat_file="`pwd`/test_$1_dstat.csv"
    tempfile=`mktemp`
    cat $dstat_file | sed -e '/^"/d' | sed -e "/^$/d" | sed -e "s/\([0-9][0-9]\)-\([0-9][0-9]\) \([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\),\(.*\)/\"2016\/\2\/\1\ \3\",\4/g" > $tempfile
    mv $tempfile $dstat_file
    cat <<EOF >> $LOAD_FILE
create table dstat_$num (time timestamp, usr real, sys real, idl real, wai real, hiq real, siq real, read real, writ real, recv real, send real, pin real, pout real, sys_int real, sys_csw real, used real, buff real, cach real, free real);
copy dstat_$num from '$dstat_file' (format csv, header off);
EOF

    # Process TPS file generated by pgbench
    pgbench_file="`pwd`/test_$1_pgbench.log"
    tempfile=`mktemp`
    cat $pgbench_file | cut -d " " -f 2,4,7,10 > $tempfile
    mv $tempfile $pgbench_file
    cat <<EOF >> $LOAD_FILE
create table pgbench_$num(time real, tps real, latency real, stddev real);
copy pgbench_$num from '$pgbench_file' (format csv, header off, delimiter ' ');
EOF

    # Process response file generated by pgbench
    pgbench_log="ls -1 | grep pgbench_log"
    response_file="`pwd`/response_$1.csv"
    $R_PGBENCH -d -f $pgbench_log > $response_file
    rm $pgbench_log
	cat <<EOF >> $LOAD_FILE
create table response_$1(time real, duration real);
copy response_$i from '$respone_file' (format csv);
EOF
}

# Generate sample sql for re:dash
function make_sample_sql()
{
    num=$(($1 - 1))

    # make pgbench sql
    echo "SELECT pgbench_0.time, " >> $SAMPLE_FILE
    for i in `seq 0 $num`
    do
	if [ "$i" == "$num" ]; then
	    echo "pgbench_$i.tps as \"test $i\"" >> $SAMPLE_FILE
	else
	    echo "pgbench_$i.tps as \"test $i\", " >> $SAMPLE_FILE
	fi
    done
    echo "FROM " >> $SAMPLE_FILE
    for i in `seq 0 $num`
    do
	if [ "$i" == "$num" ]; then
	    echo "pgbench_$i" >> $SAMPLE_FILE
	else
	    echo "pgbench_$i, " >> $SAMPLE_FILE
	fi
    done
    echo "WHERE " >> $SAMPLE_FILE
    for i in `seq 1 $num`
    do
	a=$i
	b=$(($i-1))
	if [ "$i" == "$num" ];then
	    echo "pgbench_$b.time = pgbench_$a.time" >> $SAMPLE_FILE
	else
	    echo "pgbench_$b.time = pgbench_$a.time and" >> $SAMPLE_FILE
	fi
    done
    echo ";" >> $SAMPLE_FILE

    # make r_monitor sql
    echo "SELECT r_monitor_0.time, " >> $SAMPLE_FILE
    for i in `seq 0 $num`
    do
	if [ "$i" == "$num" ];then
	    echo "r_monitor_$i.dirty as \"monitor_$i dirty\", " >> $SAMPLE_FILE
	    echo "r_monitor_$i.writeback as \"monitor_$i writeback\"" >> $SAMPLE_FILE
	else
	    echo "r_monitor_$i.dirty as \"monitor_$i dirty\", " >> $SAMPLE_FILE
	    echo "r_monitor_$i.writeback as \"monitor_$i writeback\", " >> $SAMPLE_FILE
	fi
    done
    echo "FROM " >> $SAMPLE_FILE
    for i in `seq 0 $num`
    do
	if [ "$i" == "$num" ]; then
	    echo "r_monitor_$i" >> $SAMPLE_FILE
	else
	    echo "r_monitor_$i, " >> $SAMPLE_FILE
	fi
    done
    echo "WHERE " >> $SAMPLE_FILE
    for i in `seq 1 $num`
    do
	a=$i
	b=$(($i-1))
	if [ "$i" == "$num" ];then
	    echo "r_monitor_$b.seqno = r_monitor_$a.seqno" >> $SAMPLE_FILE
	else
	    echo "r_monitor_$b.seqno = r_monitor_$a.seqno and" >> $SAMPLE_FILE
	fi
    done
    echo ";" >> $SAMPLE_FILE
}

test_count=0
#$PGBENCH_INIT
while read line;
do
    if [ "$line" == "@@@" ];then
	do_test $test_count
	prepare_to_load $test_count
	cp $PGCONF_ORG $PGCONF # Test done, reset config file
	test_count=$(($test_count + 1))
	continue
    fi

    echo "$line" >> $PGCONF
done < $1

make_sample_sql $test_count

# Restore configuration file
cp $PGCONF_ORG $PGCONF

echo "psql -d postgres -f $LOAD_FILE"
echo "psql -d postgres -f $SAMPLE_FILE"