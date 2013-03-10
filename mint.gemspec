# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mint/version'

Gem::Specification.new do |gem|
  gem.name          = "mint"
  gem.version       = Mint::VERSION
  gem.authors       = ["Aldric Giacomoni"]
  gem.email         = ["trevoke@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "pry-doc"
  gem.add_development_dependency "interactive_editor"
  gem.add_runtime_dependency "rails"
  gem.add_runtime_dependency "sqlite3"
end
