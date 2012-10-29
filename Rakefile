require 'bundler/setup'
require 'bundler/gem_tasks'
require 'bump/tasks'

task :default do
  # tests do not run with test-unit 1.x.x or <=2.3 since it defines testrb and overshadows 1.9s native testrb
  if `which testrb`.include?("/gems/")
    raise "tests do not run with test-unit testrb installed\nyes | gem uninstall -a test-unit && bundle"
  end

  sh "rspec spec/"
end
