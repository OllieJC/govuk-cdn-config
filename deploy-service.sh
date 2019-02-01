#!/usr/bin/env bash

set -e

# Copy secrets over into /configs
rm -rf cdn-configs
git clone git@github.com:alphagov/cdn-configs.git

cp cdn-configs/fastly/fastly.yaml .

# TODO: rename vhost to SERVICE_NAME in the Jenkins job
export SERVICE_NAME=${vhost}

bundle install --path "${HOME}/bundles/${JOB_NAME}" --deployment
bundle exec ./configure_service
