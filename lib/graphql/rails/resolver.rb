module GraphQL
  module Rails
    class Resolver
      VERSION = '0.1.3'

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
      end

      def call(obj, args, ctx)
        @obj = obj
        @args = args
        @ctx = ctx

        @result = @callable.call(obj, args, ctx)

        # If there's an ID type, offer ID resolution_strategy
        if has_id_field and args.key? :id
          lookup_id(args[:id])
        end

        @resolvers.each do |field,method|
          if args.key? field
            @result = method.call(@result, args[field])
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
          @result.all
        else
          @result.first
        end
      end

      def field_name
        @ctx.ast_node.name
      end

      def has_id_field
        @ctx.irep_node.children.any? {|x| x[1].return_type == GraphQL::ID_TYPE }
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

      def lookup_id(value)
        if is_global_id(value)
          type_name, id = NodeIdentification.from_global_id(value)
          constantized = "::#{type_name}".constantize

          if constantized == model
            @result = @result.where(:id => id)
          else
            nil
          end
        else
          @result = @result.where(:id => value)
        end
      end

      class << self

        def resolvers
          @resolvers ||= {}
          @resolvers
        end

        def resolve(field, method)
          @resolvers ||= {}
          @resolvers[field] = method
        end

        def resolve_where(field)
          resolve(field, lambda { |obj, value|
            where = {}
            where[field] = value

            obj.where(where)
          })
        end

        def resolve_scope(field, test=nil, scope_name: nil, with_value: false)
          test = lambda { |value| value.present? } if test.nil?
          scope_name = field if scope_name.nil?

          resolve(field, lambda { |obj, value|
            args = []
            args.push(value) if with_value

            if test.call(value)
              obj.send(scope_name, *args)
            else
              obj
            end
          })
        end

        def resolve_method(field)
          resolve(field, lambda { |obj, value|
            obj.send(field, value)
          })
        end
      end
    end
  end
end
