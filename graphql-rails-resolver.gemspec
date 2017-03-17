$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'graphql/rails/resolver'

Gem::Specification.new do |s|
  s.name        = 'graphql-rails-resolver'
  s.version     = GraphQL::Rails::Resolver::VERSION
  s.date        = Date.today.to_s
  s.summary     = "GraphQL + Rails integration for Field Resolvers."
  s.description = "A utility for ease graphql-ruby integration into a Rails project."
  s.authors     = ["Cole Turner"]
  s.email       = 'turner.cole@gmail.com'
  s.files       = Dir["{lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  s.homepage    = 'http://rubygems.org/gems/graphql-rails-resolver'
  s.license     = 'MIT'

  s.add_runtime_dependency "graphql", ['>= 1.5.0', '< 2.0']
  s.add_development_dependency "activerecord"
  s.required_ruby_version = '>= 2.3.0'
end
