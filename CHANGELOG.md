# GraphQL::Rails::Resolver
## CHANGELOG

### Version 0.2.8
Added argument value preprocessing using `:map` option

### Version 0.2.7
Added conditional resolution by means of `:if` and `:unless` options 

### Version 0.2.6
Fixes issue where resolution may skip over :where

### Version 0.2.5
Adds heirarchal resolution strategy

The base resolver will now check for the field's resolver method on the object. If resolving `Child` on `Parent` it will now default to `Parent.child` instead of `Child.all`

### Version 0.2.4
Adds ID resolution for non-primary ID field arguments
Adds `get_field_args` to get type declarations for arguments
Adds `get_arg_type`, `is_field_id_type?`, and `is_arg_id_type?`

### Version 0.2.2
Fixed arguments to :scope resolution

### Version 0.2.2
Changed dependency version to optimistic.

### Version 0.2.1
Added `resolve_id` that resolves a single or list of ID type objects.

### Version 0.2.0
Update to support GraphQL 0.19.0

Removes `to_model_id` and `lookup_id` functions. This functionality should be decided on the application level via `Schema.object_from_id`
Uses schema functions to resolve objects.

### Version 0.1.5
Fixed `where` method resolving superseding attribute.

### Version 0.1.4
Added `resolve` with parameters
Deprecates `resolve_where` and `resolve_scope`

### Version 0.1.3
Added `resolve_scope` for resolving model scopes.
Fixed `resolve_where` not being called and reworked class inheritance.


### Version 0.1.2
Initial release. Took a couple tries to figure out how to import to a new namespace on an existing gem.
