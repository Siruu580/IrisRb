# frozen_string_literal: true

require_relative "lib/iris_rb/version"

Gem::Specification.new do |spec|
  spec.name          = "iris_ruby"
  spec.version       = IrisRb::VERSION
  spec.authors       = ["qweruby"]
  spec.email         = ["qweruby8@gmail.com"]

  spec.summary       = "Ruby port of Iris"
  spec.description   = "A Ruby package that supports the Iris framework"
  spec.homepage      = "https://github.com/Siruu580/IrisRb"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.4.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE"
  ]

  spec.require_paths = ["lib"]
end
