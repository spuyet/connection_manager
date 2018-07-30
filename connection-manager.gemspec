
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "connection-manager/version"

Gem::Specification.new do |spec|
  spec.name          = "connection-manager"
  spec.version       = ConnectionManager::VERSION
  spec.authors       = ["Sébastien Puyet"]
  spec.email         = ["sebastien@puyet.fr"]

  spec.summary       = %q{A useful connection manager}
  spec.homepage      = "https://github.com/spuyet/connection_manager"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
