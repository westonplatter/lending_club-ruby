# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lending_club/version'

Gem::Specification.new do |spec|
  spec.name          = "lending_club-ruby"
  spec.version       = LendingClub::VERSION
  spec.authors       = ["Weston Platter"]
  spec.email         = ["westonplatter@gmail.com"]
  spec.summary       = %q{Simple wraper around the Lending Club API via Ruby}
  spec.description   = %q{See https://www.lendingclub.com/developers/lc-api.action for more info}
  spec.homepage      = "http://github.com/westonplatter/lending_club-ruby"
  spec.license       = "BSD-3"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
