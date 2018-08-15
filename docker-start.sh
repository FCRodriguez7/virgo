service mysqld start 
echo "Started mysql..."
echo "create database blacklight_development; grant all on blacklight_development.* to bldevelopment@localhost identified by 'd01pswd';" | mysql -u root 
echo "Crated bldevleopment user..."
/bin/bash -l -c "bundle exec rake db:create" 
echo "Created database..."
/bin/bash -l -c "bundle exec rake db:migrate" 
echo "Migrated database..."
/bin/bash -l -c "rails server"
