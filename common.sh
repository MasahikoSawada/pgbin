#!/bin/sh

# Can be change manually
PGHOME=.
PGPORT=5432
PGDATABASE=postgres

##### Basically don't touch below area!! ####
# Base enviroment variables
BIN=${PGHOME}/bin
PGDATA=${PGHOME}

# command path
PSQL="${BIN}/psql -p ${PGPORT} -d ${PGDATABASE}"