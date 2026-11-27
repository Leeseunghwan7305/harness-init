#!/usr/bin/env bash
set -e
git init -q
printf '%s\n' '{ "name": "calc", "type": "module", "scripts": { "test": "node --test" } }' > package.json
