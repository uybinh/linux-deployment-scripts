# Deploy Rails app to Ubuntu 18.04 server using Capistrano, Nginx on Linode

## 1. Setup server

### 1.1. Add deploy user

```
adduser deploy
```

After config password, add user deploy to sudo group

```
usermod -aG sudo deploy
```
### 1.2. Setting up SSH Keys
Create new public key on deployment server

```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Add local public key to deployment server

```
ssh-copy-id deploy@<server ip address>
```

## 2. Install rbenv, ruby 2.5.1, rails 5.2.0, nginx, postsgres

Login server as deploy user

```
curl -sL https://github.com/uybinh/linux-deployment-scripts/raw/master/rails/ubuntu18.04_rbenv.sh | bash -
```

Change ownership of "~/.rbenv/" to deploy user

```
sudo chown deploy:deploy ~/.rbenv/
```
## Set up database

```
sudo -u postgres
createuser <username>
createdb <dbname>
psql
```

```
psql=# alter user <username> with encrypted password '<password>';
```


## 3. Setup rails app
### 3.1. Adding Deployment Configurations in the Rails App

Add to gemfile
```
#Gemfile

gem 'capistrano',         require: false
gem 'capistrano-rbenv', '~> 2.1'
gem 'capistrano-rails',   require: false
gem 'capistrano-bundler', require: false
gem 'capistrano3-puma',   require: false
```

Use bundler to install the gems you just specified in your Gemfile.
```
bundle install
```

After bundling, run the following command to configure Capistrano:

```
cap install
```

This will create:
* Capfile in the root directory of your Rails app
* deploy.rb file in the config directory
* deploy directory in the config directory

Replace the contents of your Capfile with the following:

```
#Capfile

# Load DSL and Setup Up Stages
require 'capistrano/setup'
require 'capistrano/deploy'

require 'capistrano/rails'
require 'capistrano/bundler'
require 'capistrano/puma'
require 'capistrano/rbenv'
install_plugin Capistrano::Puma
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

```
This Capfile loads some pre-defined tasks in to your Capistrano configuration files to make your deployments hassle-free, such as automatically:

* Selecting the correct Ruby
* Pre-compiling Assets
* Cloning your Git repository to the correct location
* Installing new dependencies when your Gemfile has changed

Replace the contents of config/deploy.rb with the following, updating fields marked in red with your app and Droplet parameters:

> replace 'your_server_ip', 'appname', 'deploy', github address with yours
>
> you can remove 'port: your_port_num'

```
#config/deploy.rb

# Change these
server 'your_server_ip', port: your_port_num, roles: [:web, :app, :db], primary: true

set :repo_url,        'git@example.com:username/appname.git'
set :application,     'appname'
set :user,            'deploy'
set :puma_threads,    [4, 16]
set :puma_workers,    0

# Don't change these unless you know what you're doing
set :pty,             true
set :use_sudo,        false
set :stage,           :production
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to false when not using ActiveRecord
set :linked_files, %w{config/master.key}

# config rbenv
set :rbenv_type, :deploy # or :system, depends on your rbenv setup
set :rbenv_ruby, '2.5.1'

# in case you want to set ruby version from the file:
# set :rbenv_ruby, File.read('.ruby-version').strip

set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails puma pumactl}
set :rbenv_roles, :all # default value

## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5

## Linked Files & Directories (Default None):
# set :linked_files, %w{config/database.yml}
# set :linked_dirs,  %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        puts "WARNING: HEAD is not the same as origin/master"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke! 'puma:restart'
    end
  end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma
```
Create config/nginx.conf in your Rails project directory

```
#config/nginx.conf

upstream puma {
  server unix:///home/deploy/apps/appname/shared/tmp/sockets/appname-puma.sock;
}

server {
  listen 80 default_server deferred;
  # server_name example.com;

  root /home/deploy/apps/appname/current/public;
  access_log /home/deploy/apps/appname/current/log/nginx.access.log;
  error_log /home/deploy/apps/appname/current/log/nginx.error.log info;

  location ^~ /assets/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }

  try_files $uri/index.html $uri @puma;
  location @puma {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_redirect off;

    proxy_pass http://puma;
  }

  error_page 500 502 503 504 /500.html;
  client_max_body_size 10M;
  keepalive_timeout 10;
}
```

## 4. Deploying your Rails Application
```
git add *
git commit -m "Set up Puma, Nginx & Capistrano"
git push origin master
cap production deploy:initial
```
> On the Droplet, Symlink the nginx.conf to the sites-enabled directory:

```
sudo rm /etc/nginx/sites-enabled/default
sudo ln -nfs "/home/deploy/apps/appname/current/config/nginx.conf" "/etc/nginx/sites-enabled/appname"

sudo service nginx restart
```

> If you make changes to your config/nginx.conf file, you'll have to reload or restart your Nginx service on the server after deploying your app
```
sudo service nginx restart
```

## Fix error with Rails 5.2.0
[Deploying Rails 5.2 Applications with New Encrypted Credentials using Capistrano](http://waiyanyoon.com/deploying-rails-5-2-applications-with-encrypted-credentials-using-capistrano/)

> Copy config/master.key to your server manually without commiting to git

1. Copy config/master.key in your local to the production server under <project_root>/shared/config/master.key. If you don't have the key, please get it from your colleagues or whoever that initialized the Rails app.
2. Configure your capistrano's config/deploy.rb to include this line:

```
set :linked_files, %w{config/master.key}
```

3. Deploy your app again and verify that deployment is successful.
4. Commit this changes to your repo. Don't check-in your config/master.key!

## Notes

* Remember to create an SSH key on local machine for circle ci
  * add the private key to circle ci
  * add the public key to authorized keys on server