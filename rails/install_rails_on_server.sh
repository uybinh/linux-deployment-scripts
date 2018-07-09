#!/usr/bin/env bash
#
#
# Linode deployment
# deployment #linode

# Deploying a Rails App on Ubuntu 14.04 with Capistrano, Nginx, and Puma
# 1. Installing Nginx

sudo apt-get update
sudo apt-get install curl git-core nginx -y

# 2. Installing Databases
# Postgresql
# Guide on unbuntu 18.04
# sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
# wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | sudo apt-key add -
# sudo apt-get update
# sudo apt-get install postgresql-common -y
# sudo apt-get install postgresql-9.5 libpq-dev -y

# Guide on DigitalOcean
sudo apt-get install postgresql postgresql-contrib libpq-dev

# create user
# sudo -u postgres createuser -s pgbinh
# set password
# sudo -u postgres psql

#3. Install Ruby
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update
sudo apt-get install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev software-properties-common libffi-dev nodejs yarn -y

# 4. Install rvm
sudo apt-get install libgdbm-dev libncurses5-dev automake libtool bison libffi-dev -y
sudo gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | sudo bash -s stable
source ~/.rvm/scripts/rvm
rvm install 2.5.1
rvm use 2.5.1 --default

# check install successful
# ruby -v

# install bundler
gem install bundler

# 5. Install Rails
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt-get install -y nodejs

gem install rails -v 5.2.0