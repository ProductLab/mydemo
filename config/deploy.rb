#######################################################################
# Please change the following variables to fit the requirements of 
# RoR application, if needed.
#
# :application
# :rails_env
# :repository
# :branch
# :listen
# :server_name
# :root 
# :web
# :app
# :db
########################################################################

require "bundler/capistrano" 
require "rvm/capistrano"

# ruby-1.9.3-p194@working is a working repository when deploying the RoR applications
set :rvm_ruby_string, 'ruby-1.9.3-p194@working'
set :rvm_type, :system 

# The deployment script will run under the :user account to deploy the RoR applications locally or remotely.
set :user, "www-data"
set :use_sudo, false 
set :deployer, "login"
# The name of the RoR application for the deployment.
set :application, "mydemo"
# An application directory based on the name of the RoR application will be created under /var/www directory of the app server.
set :deploy_to, "/var/www/#{application}"
# The Rails application environmenti. It could be "development", "production", or "test".
set :rails_env, "development"

# Skip the gems of the test group for development deployment
if fetch(:rails_env) == "development"
	 set :bundle_without, [:test]
end

# Skip the gems of the development group for test deployment
if fetch(:rails_env) == "test"
	 set :bundle_without, [:development]
end

# The Git repository of the source code and other artificats of the RoR applications.
set :repository, "git@github.com:eraserx99/mydemo.git"
# The branch of the Git repository.
set :branch, "master"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

# The TCP port of the HTTP server.
set :listen, 80
# The DNS name of the HTTP server. It can be the DNS name assigned to this RoR application or just localhost.
set :server_name, "localhost"
# The document root of the RoR application.
set :root, "#{deploy_to}/current/public"

# The location of the sites-available directory that is used to store the Nginx configuration files for available sites.
# The available sites might be active or inactive. It depends on if there is a link created from the sites-enabled directory.
set :sites_available, "/opt/nginx/conf/sites-available"
# The location of the sites-enabled directory that is used to store the symbolic links to the Nginx configuration files.
# Each of the links represents an active site.
set :sites_enabled, "/opt/nginx/conf/sites-enabled"

# The server location of the HTTP server, Nginx/Apache.
role :web, "localhost"                
# The server location of the application. It is usually the same as the HTTP server.
role :app, "localhost"                               
# The server location of the database server. This is where Rails migrations will run.
role :db,  "localhost", :primary => true

default_run_options[:pty] = true

# Helper methods
def close_sessions
	sessions.values.each { |session| session.close }
	sessions.clear
end

def create_tmp_file(contents)
	system 'mkdir tmp'
	file = File.new("tmp/#{application}", "w")
	file << contents
	file.close
end

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
	task :start do ; end
	task :stop do ; end
	task :restart, :roles => :app, :except => { :no_release => true } do
		# nginx.reload_application might not work under some scenarios. 
		# nginx.restart is used instead.
		# nginx.reload_application
		nginx.restart
	end
end

namespace :nginx do

	desc "Create the application deployment directory under /var/www"
	task :prepare, :roles => :app, :except => { :no_release => true } do
		run "test -d #{deploy_to} || mkdir -p #{deploy_to}"
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		close_sessions
		run "sudo sh -c \"test -f #{sites_available}/#{application}.conf || cp #{sites_available}/default.conf.template #{sites_available}/#{application}.conf\""
		run "sudo sh -c \"test -L #{sites_enabled}/#{application}.conf || ln -s #{sites_available}/#{application}.conf #{sites_enabled}/#{application}.conf\""
		run "sudo sh -c \"sed -i -e's|%listen%|#{listen}|g' #{sites_available}/#{application}.conf\""
		run "sudo sh -c \"sed -i -e's|%server_name%|#{server_name}|g' #{sites_available}/#{application}.conf\""
		run "sudo sh -c \"sed -i -e's|%root%|#{root}|g' #{sites_available}/#{application}.conf\""
		run "sudo sh -c \"sed -i -e's|%rails_env%|#{rails_env}|g' #{sites_available}/#{application}.conf\""
		set :user, "#{old_user}"
		close_sessions
	end

	desc "Restart Nginx"
	task :restart, :roles => :app, :except => { :no_release => true } do
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		close_sessions
		run "/usr/bin/sudo /usr/bin/service nginx restart"
		set :user, "#{old_user}"
		close_sessions
	end

	desc "Stop Nginx"
	task :stop, :roles => :app, :except => { :no_release => true } do
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		run "/usr/bin/sudo /usr/sbin/service nginx stop"
		set :user, "#{old_user}"
		close_sessions
	end

	desc "Start Nginx"
	task :start, :roles => :app, :except => { :no_release => true } do
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		run "/usr/bin/sudo /usr/sbin/service nginx start"
		set :user, "#{old_user}"
		close_sessions
	end

	desc "Request to reload the application"
	task :reload_application, :roles => :app, :except => { :no_release => true } do
		run "touch #{File.join(current_path,'tmp','restart.txt')}"
	end

	desc "Remove a virtual host"
	task :remove_virtual_host, :roles => :app, :except => { :no_release => true } do
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		run "/usr/bin/sudo /usr/sbin/service nginx stop"
		run "/usr/bin/sudo rm -f #{sites_enabled}/#{application}.conf"
		run "/usr/bin/sudo rm -f #{sites_available}/#{application}.conf"
		run "/usr/bin/sudo /usr/sbin/service nginx start"
		set :user, "#{old_user}"
		close_sessions
	end

	desc "Disable a virtual host"
	task :disable_virtual_host, :roles => :app, :except => { :no_release => true } do
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		run "/usr/bin/sudo /usr/sbin/service nginx stop"
		run "/usr/bin/sudo rm -f #{sites_enabled}/#{application}.conf"
		run "/usr/bin/sudo /usr/sbin/service nginx start"
		set :user, "#{old_user}"
		close_sessions
	end

	desc "Remove the application"
	task :remove_application, :roles => :app, :except => { :no_release => true } do
		set :old_user, "#{user}" 
		set :user, "#{deployer}" 
		run "/usr/bin/sudo /usr/sbin/service nginx stop"
		run "/usr/bin/sudo rm -f #{sites_enabled}/#{application}.conf"
		run "/usr/bin/sudo rm -f #{sites_available}/#{application}.conf"
		run "/usr/bin/sudo rm -rf #{deploy_to}"
		run "/usr/bin/sudo /usr/sbin/service nginx start"
		set :user, "#{old_user}"
		close_sessions
	end
end

before "deploy:setup", "nginx:prepare"

# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

