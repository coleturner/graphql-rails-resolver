# GraphQL::Rails::Resolver (graphql-rails-resolver)
A utility to ease graphql-ruby integration into a Rails project. This resolver offers a declarative approach to resolving Field arguments in a Rails environment.

# How it works
`GraphQL::Rails::Resolver` serves as a base class for your GraphQL Ruby schema. When a resolver inherits from this base class, you can easily map arguments in a GraphQL Field to an attribute on an ActiveRecord model or a custom method.

## Why?
**tl;dr; To achieves three goals: maintainable query type, code re-use, and a declarative integration with Ruby on Rails.**

Take for example the following Rails model:

```
class Post < ApplicationRecord
  belongs_to :author
  has_many :comments

  scope :is_public, -> { where(is_public: true) }
  scope :is_private, -> { where(is_public: false) }
  scope :featured, -> (value) { where(created_at: value) }

  def tags
     ["hello", "world"]
  end

end
```

The standard implementation for resolving a `Post` is as follows:

```
field :post, PostType do
  argument :is_public, types.Boolean, default_value: true
  resolve -> (obj, args, ctx) {
    post.is_public if args[:is_public]
    post.is_private unless args[:is_public]
  }
end
```

This implementation is cumbersome and when your application grows it will become unmanageable. In [GraphQL Ruby: Clean Up your Query Type](https://m.alphasights.com/graphql-ruby-clean-up-your-query-type-d7ab05a47084) we see a better pattern emerge for building resolvers that can be re-used.

Using the pattern from this article, our Field becomes much simpler:

**/app/graph/types/query_type.rb**
```
field :post, PostType do
  argument :is_public, types.Boolean, default_value: true
  resolve Resolvers::Post.new
end
```

**/app/graph/resolvers/post.rb**
```
module Resolvers
  class Post
    def call(_, arguments, _)
      if arguments[:ids]
        ::Post.where(id: arguments[:ids])
      elsif arguments.key? :is_public
        ::Post.is_public if arguments[:is_public]
        ::Post.is_private unless arguments[:is_public]
      else
        ::Post.all
      end
    end
  end
end
```
This solution addresses code re-use, but these series of conditionals do not allow you to resolve more than one argument, and it may become difficult to maintain this imperative approach.


## Hello "Active" Resolver
**Out with imperative, in with declarative.**

To begin, we install the gem by adding it to our `Gemfile`:

`
gem 'graphql-rails-resolver'
`

This will load a class by the name of `GraphQL::Rails::Resolver`

Take the Resolver from the previous example. Using `GraphQL::Rails::Resolver`, we inherit and use declarations for arguments and how they will be resolved. These declarations will be mapped to the attributes on the resolved model.

```
# Class name must match the Rails model name exactly.

class Post < GraphQL::Rails::Resolver
  # ID argument is resolved in base class

  # Resolve :is_public to a class method
  resolve_method :is_public

  # Resolve :title, :created_at, :updated_at to Post.where() arguments
  resolve_where :title
  resolve_where :created_at
  resolve_where :updated_at

  # Resolve :featured argument with default test: if argument `featured` is present
  resolve_scope :featured

  # Same resolution as the line above, but send the value to the scope function
  resolve_scope :featured, :with_value => true

  # Resolve :featured scope if it passes custom argument test
  resolve_scope :featured, -> (value) { value == :today }

  # Resolve :is_public argument with a different scope name
  resolve_scope :is_public, -> (value) { value != true }, :scope_name => :is_private

  def is_public(value)
    @result.is_public if value
    @result.is_private unless value
  end

end
```

In the example above, there are three declarations:

`resolve_where` is a declarative approach using `ActiveRecord.where` to resolve arguments.

`resolve_scope` is an declarative way to call scopes on a model where a custom test for the argument can be specified with a closure.
- Use `with_value` to send the argument value to the scope closure.
- Use `scope_name` to map an argument to a scope by another name.

`resolve_method` is an imperative approach that allows completely custom resolution.




### Detecting the Model
The resolver will automatically resolve to a Rails model with the same name. This behavior can be overridden by defining a `Post#model` which returns the appropriate model.
```
def model
   ::AnotherModel
end
```

### Find Model by ID
`GraphQL::Rails::Resolver` includes the ability to resolve a model by ID. Using the following method, by default the resolver will find a model by **NodeIdentification.from_global_id(value)** or **Model.where(:id => value)**. This means a model can be resolved by Global ID or Integer ID.
```
def lookup_id(value)
  ...
end
```


### Override Default Scope
The default behavior is to use `Model.all` to scope the resolution. This scope can be changed by providing a block or lambda to the class instance:
```
Resolvers::Post.new(Proc.new {
	::Post.where(:created_at => ...)
})
```


# Needs Help
I wanted to release this utility for the hopes of sparking interest in Rails integration with `graphql-ruby`. If you wish to contribute to this project, any pull request is warmly welcomed. 

# Credits
- Cole Turner ([@colepatrickturner](https://github.com/colepatrickturner))
- Peter Salanki ([@salanki](https://github.com/salanki))
