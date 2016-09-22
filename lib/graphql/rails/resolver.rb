module GraphQL
  module Rails
    class Resolver
      VERSION = '0.1.2'

      def initialize(callable=nil)
        unless callable.nil?
          raise ArgumentError, "Resolver requires a callable type or nil" unless callable.respond_to? :call
        end

        @callable = callable || Proc.new { model.all }
        @obj = nil
        @args = nil
        @ctx = nil
        @resolvers = {}
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
            method
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

      def self.resolve(field, method)
        self.class_eval do
          @resolvers[field] = method
        end
      end

      def self.resolve_where(field)
        self.class_eval do
          resolve(field, Proc.new {
            @result = @result.where(field, @args[field])
          })
        end
      end

      def self.resolve_method(field)
        self.class_eval do
          resolve(field, Proc.new {
            send(field, @args[field])
          })
        end
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


    end
  end
end
