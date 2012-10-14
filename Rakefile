require 'bundler/setup'
require 'bundler/gem_tasks'

task :default do
  # tests do not run with test-unit 1.x.x or <=2.3 since it defines testrb and overshadows 1.9s native testrb
  if `which testrb`.include?("/gems/")
    raise "tests do not run with test-unit testrb installed\nyes | gem uninstall -a test-unit && bundle"
  end

  sh "rspec spec/"
end

# extracted from https://github.com/grosser/project_template
rule /^version:bump:.*/ do |t|
  sh "git status | grep 'nothing to commit'" # ensure we are not dirty
  index = ['major', 'minor','patch'].index(t.name.split(':').last)
  file = 'lib/testrbl/version.rb'

  version_file = File.read(file)
  old_version, *version_parts = version_file.match(/(\d+)\.(\d+)\.(\d+)/).to_a
  version_parts[index] = version_parts[index].to_i + 1
  version_parts[2] = 0 if index < 2 # remove patch for minor
  version_parts[1] = 0 if index < 1 # remove minor for major
  new_version = version_parts * '.'
  File.open(file,'w'){|f| f.write(version_file.sub(old_version, new_version)) }

  sh "bundle && git add #{file} Gemfile.lock && git commit -m 'bump version to #{new_version}'"
end
