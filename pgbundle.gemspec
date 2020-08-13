# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pgbundle/version'

Gem::Specification.new do |spec|
  spec.name          = "pgbundle"
  spec.version       = Pgbundle::VERSION
  spec.authors       = ["Manuel Kniep"]
  spec.email         = ["manuel@adjust.com"]
  spec.summary       = %q{bundling postgres extension}
  spec.description   = %q{bundler like postgres extension manager}
  spec.homepage      = "http://github.com/adjust/pgbundle"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'thor'
  spec.add_dependency 'net-ssh'
  spec.add_dependency 'net-scp'
  spec.add_dependency 'zip'
  #https://bitbucket.org/ged/ruby-pg/wiki/Home
  spec.add_dependency 'pg', '> 0.17'
  spec.add_development_dependency 'rspec', '~> 2.14.0'
  spec.add_development_dependency "bundler", ">= 1.5.0"
  spec.add_development_dependency "rake", "<= 11.0.0"
end
