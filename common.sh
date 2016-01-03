#!/bin/sh

# Can be change manually
PGHOME=.
PGPORT=5432
PGDATABASE=postgres

##### Basically don't touch below area!! ####
# Base enviroment variables
PGBIN=${PGHOME}/bin
PGDATA=${PGHOME}/data

# command path
PSQL="${PGBIN}/psql -p ${PGPORT} -d ${PGDATABASE}"