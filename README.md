# GraphQL::Rails::Resolver (graphql-rails-resolver)
A utility for ease graphql-ruby integration into a Rails project. This resolver offers a declarative approach to resolving Field arguments in a Rails environment.

# How it works:
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
This solution addresses code re-use, however this series of conditionals do not allow you to resolve more than one argument, and it may become difficult to maintain this imperative approach.


## Hello "Active" Resolver:
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

  def is_public(value)
    @result.is_public if value
    @result.is_private unless value
  end

end
```

In the example above, there are two declarations:

`resolve_where` is a declarative approach using `ActiveRecord.where` to resolve arguments.

`resolve_method` is an imperative approach that's useful for using Model scopes or custom resolution.

[Help make scopes declarative!](#making-scopes-declarative)




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


### Override Default Resolution
The default behavior is to use `Model.all` to seed the resolution. This seed can be changed by providing a block or lambda to the class instance:
```
Resolvers::Post.new(Proc.new {
	::Post.where(:created_at => ...)
})
```


# Needs Help
I wanted to release this utility for the hopes of sparking interest in Rails integration with `graphql-ruby`.

If you wish to contribute to this project, any pull request is warmly welcomed. If time permits, I will continue to update this project to achieve the following:

### [Making Scopes Declarative](#making-scopes-declarative):
For first release, scopes can only be resolved using `resolve_method`. The goal for further development is to stop using `resolve_method` and adapt other methods to facilitate resolution.

The current syntax planned for scope resolution is as follows, where the argument is passed to the scope:

```
resolve_scope :is_public, -> (args) { args[:is_public] == true }
resolve_scope :is_private, -> (args) { args[:is_public] == false }
```



# Credits
- Cole Turner ([@colepatrickturner](/colepatrickturner))
- Peter Salanki ([@salanki](/salanki))
