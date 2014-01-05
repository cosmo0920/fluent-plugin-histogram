# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-histogram"
  gem.version       = "0.1.0"
  gem.authors       = ["SHIMIZU Yusuke"]
  gem.email         = "a.ryuklnm@gmail.com"
  gem.description   = "Combine inputs data and make histogram which help to detect a hotspot."
  gem.summary       = "Combine inputs data and make histogram which help to detect a hotspot."
  gem.homepage      = "https://github.com/karahiyo/fluent-plugin-histogram"
  gem.license       = "APLv2"

  gem.rubyforge_project = "fluent-plugin-histogram"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "bundler", "~> 1.3"
  gem.add_development_dependency "rake", ">= 0.9.2"
  gem.add_development_dependency "fluentd", "~> 0.10.9"
  gem.add_runtime_dependency "fluent-mixin-config-placeholders", "~> 0.2.3"

end
