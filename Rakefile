# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require(File.join(File.dirname(__FILE__), 'config', 'boot'))
require(File.join(RAILS_ROOT, 'vendor', 'gems', 'jscruggs-metric_fu-1.0.1', 'lib', 'metric_fu'))

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'tasks/rails'

# add vendor/gems gems to load path
Dir[ File.join(RAILS_ROOT, 'vendor', 'gems', '*', 'lib') ].each do |gem_lib_dir|
  $LOAD_PATH << gem_lib_dir
end

require 'scenarios/tasks'
Scenario.load_paths = [ File.join(RAILS_ROOT, 'scenarios') ]
Scenario.before do
  require File.join(RAILS_ROOT, 'spec', 'factories')
end
# Scenario.verbose = true
