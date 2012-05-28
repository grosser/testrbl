$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "rbt"
require "#{name}/version"

Gem::Specification.new name, RBT::VERSION do |s|
  s.summary = "Run ruby Test::Unit/Shoulda tests by line-number / folder / the dozen"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.executables = ["rbt"]
  s.license = 'MIT'
end
