# GraphQL::Rails::Resolver
## CHANGELOG

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
