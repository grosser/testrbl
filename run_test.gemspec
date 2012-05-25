$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "run_test"
require "#{name}/version"

Gem::Specification.new name, RunTest::VERSION do |s|
  s.summary = "Run ruby Test::Unit tests by line-number or folder"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = 'MIT'
end
