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

  # Resolve :title, :created_at, :updated_at to Post.where() arguments
  resolve :title
  resolve :createdAt, :where => :created_at
  resolve :updatedAt, :where => :updated_at
  
  # Condition resolution on title being present using the `unless` option
  resolve :title, unless: -> (value) { value.blank? }

  # Resolve :title but preprocess the argument value first (strip leading/trailing spaces)
  resolve :title, map: -> (value) { value.strip }

  # Resolve :featured argument with default test: if argument `featured` is present
  resolve :featured, :scope => :featured

  # Same resolution as the line above, but send the value to the scope function
  resolve :featured, :scope => :featured, :with_value => true

  # Resolve :featured scope to a dynamic scope name
  resolve :is_public, :scope => -> (value) { value == true ? :is_public : :is_private}

  # Resolve :is_public to a class method
  resolve :custom_arg, :custom_resolve_method

  def custom_resolve_method(value)
    ...
  end

  # Resolve :is_public to a method on the model object
  resolve :custom_arg, :model_obj_method

end
```

In the examples above, the three primary arguments to `resolve` are:

`resolve :argument_name, ...`

`where` to specify another attribute.

`scope` to specify a scope on the model:
- `scope` accepts string/symbol "scope name" or a closure that returns a scope name or `nil`
- Use `with_value` to send the argument value to the scope closure.

Alternatively you can specify a symbol representing a method name: (ie: `resolve :arg_1, :custom_method`). The resolver will use it's own method if it exists, or else it will call the method on the object itself.

### Conditional resolution
Sometimes it is necessary to condition resolution of an argument on its value. For instance, by default
an empty string as an argument matches only records whose corresponding field is an empty string as well.
However, you may want an empty argument to mean that this argument should be ignored and all records shall
be matched. To achieve this, you would condition resolution of that argument on it being not empty.
    
You can condition resolution by passing the `:if` or `:unless` option to the `resolve` method. This option
can take a method name (as a symbol or a string), or a `Proc` (or lambda expression for that matter), which
will be called with the argument's value:

```
resolve :tagline, unless: -> (value) { value.blank? }

resolve :tagline, if: -> (value) { value.present? }

resolve :tagline, if: :check_value

def check_value(value)
   value.present?
end
```
    
### Preprocessing argument values
You can alter an argument's value before it is being resolved. To do this, pass a method
name (as a symbol or a string), or a `Proc` (or lambda expression) to the `:map` option
of `resolve`. The method or `Proc` you specify is then passed the original argument value
and expected to return the value that shall be used for resolution.
 
This comes in handy in various cases, for instance when you need to make sure that an
argument value is well-defined:

```
resolve :offset, map: -> (value) { [value, 0].max }
resolve :limit, map: -> (value) { [value, 100].min }
```

The above example guarantees that the offset is never negative and that the limit is
capped at a reasonable value (for [security reasons](https://rmosolgo.github.io/graphql-ruby/queries/security)).

### Detecting the Model
The resolver will automatically resolve to a Rails model with the same name. This behavior can be overridden by defining a `Post#model` which returns the appropriate model.
```
def model
   ::AnotherModel
end
```

### Find Model by ID
`GraphQL::Rails::Resolver` includes the ability to resolve an object by ID (or a list of ID types). Using the following method, by default the resolver will find a model by **Schema.object_from_id(value)**.
```
def object_from_id(value=...)
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
- Jonas Schwertfeger ([@jschwertfeger](https://github.com/jschwertfeger))
