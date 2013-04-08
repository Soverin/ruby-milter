# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'milter/version'

Gem::Specification.new do |spec|
  spec.name          = "milter"
  spec.version       = Milter::VERSION
  spec.authors       = ["Markus Strauss"]
  spec.email         = ["Markus@ITstrauss.eu"]
  # spec.description   = %q{A pure Ruby Milter library}
  spec.summary       = %q{A pure Ruby Milter library}
  spec.homepage      = "https://github.com/mstrauss/ruby-milter.git"
  # spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_dependency "eventmachine", "~> 1.0"
end
