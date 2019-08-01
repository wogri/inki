#!/bin/bash

# clean ./tmp directory
# # because if e.g. pid is already present -> rails won't start.
rm -rf ./tmp/*

# start development server
bash -l -c "bundle exec rails server -p 3000 -b 0.0.0.0"
