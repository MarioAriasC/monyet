#!/usr/bin/env bash
crystal tool format
shards install
crystal bin/ameba.cr