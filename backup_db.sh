#!/bin/sh

pg_dump -U cctools cctools-prod > proddb.backup
