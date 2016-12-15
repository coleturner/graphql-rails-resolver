module GraphQL
  module Rails
    class Resolver
      VERSION = '0.2.8'

      attr_accessor :resolvers

      def initialize(callable=nil)
        unless callable.nil?
          raise ArgumentError, "Resolver requires a callable type or nil" unless callable.respond_to? :call
        end

        @callable =
          if callable.present?
            callable
          else
            Proc.new { |obj|
              subfield = model.name.underscore.pluralize
              if obj.respond_to? subfield
                obj.send(subfield)
              else
                model.all
              end
            }
          end

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
        if has_id_argument? and args.key? @id_field
          @result = resolve_id(args[@id_field])
        end

        @resolvers.each do |arg, resolvers|
          if args.key? arg
            original_value = args[arg]

            resolvers.each do |method, params|
              next unless condition_met?(params.fetch(:if, nil), true, original_value)
              next unless condition_met?(params.fetch(:unless, nil), false, original_value)
              value = map_value(params.fetch(:map, nil), original_value)

              # Match scopes
              if params.key? :scope
                scope_name = params[:scope]
                scope_name = scope_name.call(value) if scope_name.respond_to? :call

                scope_args = []
                scope_args.push(value) if params.key? :with_value and params[:with_value] == true

                @result = @result.send(scope_name, *scope_args) unless scope_name.nil?
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
              else
                # Resolve ID arguments
                if is_arg_id_type? arg
                  value = resolve_id(value)
                end

                if self.respond_to? arg and params[:where].present? == false
                  @result = send(arg, value)
                elsif @result.respond_to? arg and params[:where].present? == false
                  @result = @result.send(arg, value)
                elsif @result.respond_to? :where
                  attribute =
                    if params[:where].present?
                      params[:where]
                    else
                      arg
                    end

                  unless @result.has_attribute?(attribute)
                    raise ArgumentError, "Unable to resolve attribute #{attribute} on #{@result}"
                  end

                  hash = {}
                  hash[attribute] = value
                  @result = @result.where(hash)
                else
                  raise ArgumentError, "Unable to resolve argument #{arg} in #{self}"
                end
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

      def has_id_argument?
        @ctx.irep_node.definitions.any? do |type_defn, field_defn|
          if field_defn.name === field_name
            field_defn.arguments.any? do |k,v|
              is_field_id_type?(v.type)
            end
          else
            false
          end
        end
      end

      def has_id_argument
        warn "[DEPRECATION] `has_id_argument` is deprecated.  Please use `has_id_argument?` instead."
        has_id_argument?
      end

      def has_id_field
        warn "[DEPRECATION] `has_id_field` is deprecated.  Please use `has_id_argument` instead."
        has_id_argument?
      end

      def connection?
        @ctx.irep_node.definitions.all? { |type_defn, field_defn| field_defn.resolve_proc.is_a?(GraphQL::Relay::ConnectionResolve) }
      end

      def list?
        @ctx.irep_node.definitions.all? { |type_defn, field_defn| field_defn.type.kind.eql?(GraphQL::TypeKinds::LIST) }
      end

      def get_field_args
        @ctx.irep_node.parent.return_type.get_field(@ctx.irep_node.definition_name).arguments
      end

      def get_arg_type(key)
        args = get_field_args
        args[key].type
      end

      def is_field_id_type?(field)
         field == ::GraphQL::ID_TYPE or
              (field.kind == ::GraphQL::TypeKinds::LIST and field.of_type == ::GraphQL::ID_TYPE)
      end

      def is_arg_id_type?(key)
         is_field_id_type?(get_arg_type(key))
      end

      def model
        unless self.class < Resolvers::Base
          raise ArgumentError, "Cannot call `model` on BaseResolver"
        end

        "::#{self.class.name.demodulize}".constantize
      end

      def resolve_id(value)
        if value.kind_of? Array
          value.compact.map { |v| @ctx.schema.object_from_id(v, @ctx) }.compact
        else
          @ctx.schema.object_from_id(value, @ctx)
        end
      end

      def condition_met?(conditional, expectation, value)
        if conditional.respond_to? :call
          conditional.call(value) == expectation
        elsif (conditional.is_a?(Symbol) || conditional.is_a?(String)) && self.respond_to?(conditional)
          self.send(conditional, value) == expectation
        else
          true
        end
      end

      def map_value(mapper, value)
        if mapper.respond_to? :call
          mapper.call(value)
        elsif (mapper.is_a?(Symbol) || mapper.is_a?(String)) && self.respond_to?(mapper)
          self.send(mapper, value)
        else
          value
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

        def resolve(arg, definition=nil, **otherArgs)
          @resolvers ||= {}
          @resolvers[arg] ||= []
          @resolvers[arg].push([definition, otherArgs])
        end

        def resolve_where(arg)
          warn "[DEPRECATION] `resolve_where` is deprecated.  Please use `resolve` instead."
          resolve(arg)
        end

        def resolve_scope(arg, test=nil, scope_name: nil, with_value: false)
          warn "[DEPRECATION] `resolve_scope` is deprecated.  Please use `resolve` instead."
          test = lambda { |value| value.present? } if test.nil?
          scope_name = arg if scope_name.nil?

          resolve(arg, :scope => -> (value) { test.call(value) ? scope_name : nil }, :with_value => with_value)
        end

        def resolve_method(arg)
          warn "[DEPRECATION] `resolve_method` is deprecated.  Please use `resolve` instead."
          resolve(arg)
        end
      end
    end
  end
end
