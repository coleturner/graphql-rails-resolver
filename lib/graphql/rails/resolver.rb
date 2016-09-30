module GraphQL
  module Rails
    class Resolver
      VERSION = '0.1.6'

      attr_accessor :resolvers

      def initialize(callable=nil)
        unless callable.nil?
          raise ArgumentError, "Resolver requires a callable type or nil" unless callable.respond_to? :call
        end

        @callable = callable || Proc.new { model.all }
        @obj = nil
        @args = nil
        @ctx = nil
        @resolvers = self.class.resolvers
        @id_field = self.class.id_field
      end

      def call(obj, args, ctx)
        @obj = obj
        @args = args
        @ctx = ctx

        @result = @callable.call(obj, args, ctx)

        # If there's an ID type, offer ID resolution_strategy
        if has_id_argument and args.key? @id_field
          lookup_id(args[@id_field])
        end

        @resolvers.each do |field,resolvers|
          if args.key? field
            value = args[field]

            resolvers.each do |method, params|
              # Match scopes
              if params.key? :scope
                scope_name = params[:scope]
                scope_name = scope_name.call(value) if scope_name.respond_to? :call

                scope_args = []
                scope_args.push(value) if params.key? :with_value && params[:with_value] == true

                @result = @result.send(scope_name) unless scope_name.nil?
              # Match custom methods
              elsif params.key? :method
                @result = send(params[:method], value)
              elsif method.present?
                # Match first param
                if method.respond_to? :call
                  # Match implicit blocks
                  @result = method.call(value)
                elsif self.respond_to? method
                  # Match method name to current resolver class
                  @result = send(method, value)
                elsif @result.respond_to? method
                  # Match method name to object
                  @result = @result.send(method, value)
                else
                  raise ArgumentError, "Unable to resolve parameter of type #{method.class} in #{self}"
                end
              elsif params.size < 1
                if self.respond_to? field and params[:where].present? == false
                  @result = send(field, value)
                elsif @result.respond_to? field and params[:where].present? == false
                  @result = @result.send(field, value)
                else
                  attribute =
                    if params[:where].present?
                      params[:where]
                    else
                      field
                    end

                  hash = {}
                  hash[attribute] = value
                  @result = @result.where(hash)
                end
              else
                raise ArgumentError, "Unable to resolve field #{field} in #{self}"
              end
            end
          end
        end

        result = payload

        @obj = nil
        @args = nil
        @ctx = nil

        result
      end

      def payload
        # Return all results if it's a list or a connection
        if connection? or list?
          @result
        else
          @result.first
        end
      end

      def field_name
        @ctx.ast_node.name
      end

      def has_id_argument
        @ctx.irep_node.definitions.any? do |type_defn, field_defn|
          if field_defn.name === field_name
            field_defn.arguments.any? do |k,v|
              v.type == ::GraphQL::ID_TYPE or
              (v.type.kind == ::GraphQL::TypeKinds::LIST and v.type.of_type == ::GraphQL::ID_TYPE)
            end
          else
            false
          end
        end
      end

      def has_id_field
        warn "[DEPRECATION] `has_id_field` is deprecated.  Please use `has_id_argument` instead."
        has_id_argument
      end

      def connection?
        @ctx.irep_node.definitions.all? { |type_defn, field_defn| field_defn.resolve_proc.is_a?(GraphQL::Relay::ConnectionResolve) }
      end

      def list?
        @ctx.irep_node.definitions.all? { |type_defn, field_defn| field_defn.type.kind.eql?(GraphQL::TypeKinds::LIST) }
      end

      def model
        unless self.class < Resolvers::Base
          raise ArgumentError, "Cannot call `model` on BaseResolver"
        end

        "::#{self.class.name.demodulize}".constantize
      end

      def object_from_id(value)
        if value.kind_of? Array
          value.map { |v| @ctx.schema.object_from_id(v) }.compact
        else
          @ctx.schema.object_from_id(value)
        end
      end

      class << self
        @@id_field = :id

        def id_field(value=nil)
          @@id_field = value if value.present?
          @@id_field
        end

        def resolvers
          @resolvers ||= {}
          @resolvers
        end

        def resolve(field, definition=nil, **otherArgs)
          @resolvers ||= {}
          @resolvers[field] ||= []
          @resolvers[field].push([definition, otherArgs])
        end

        def resolve_where(field)
          warn "[DEPRECATION] `resolve_where` is deprecated.  Please use `resolve` instead."
          resolve(field)
        end

        def resolve_scope(field, test=nil, scope_name: nil, with_value: false)
          warn "[DEPRECATION] `resolve_scope` is deprecated.  Please use `resolve` instead."
          test = lambda { |value| value.present? } if test.nil?
          scope_name = field if scope_name.nil?

          resolve(field, :scope => -> (value) { test.call(value) ? scope_name : nil }, :with_value => with_value)
        end

        def resolve_method(field)
          warn "[DEPRECATION] `resolve_method` is deprecated.  Please use `resolve` instead."
          resolve(field)
        end
      end
    end
  end
end
