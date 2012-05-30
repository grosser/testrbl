$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "testrbl"
require "#{name}/version"

Gem::Specification.new name, Testrbl::VERSION do |s|
  s.summary = "Run ruby Test::Unit/Shoulda tests by line-number / folder / the dozen"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.executables = ["testrbl"]
  s.license = 'MIT'
end
