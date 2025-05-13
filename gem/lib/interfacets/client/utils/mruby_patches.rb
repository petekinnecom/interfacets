# frozen_string_literal: true

module Interfacets
  module Client
    module Utils
      module MrubyPatches
        module HashExt
          NO_DEFAULT = Object.new

          def fetch(k, default = NO_DEFAULT)
            if key?(k)
              self[k]
            elsif block_given?
              yield
            elsif default == NO_DEFAULT
              raise("#{k} not found in #{inspect}")
            else
              default
            end
          end
        end

        module InspectPatch
          def inspect(...)
            "<#{self.class}:#{self.object_id}>"
          end
        end

        module ArrayPatch
          def index_by
            raise(ArgumentError) unless block_given?

            result = {}
            each { |elem| result[yield(elem)] = elem }
            result
          end
        end

        module ObjectPresence
          def blank?
            false
          end

          def present?
            !blank?
          end
        end

        module EnumerablePresence
          def blank?
            empty?
          end
        end

        module FalsyPresence
          def blank?
            true
          end
        end

        module StringPresence
          def blank?
            match?(/^\s*$/)
          end
        end

        if RUBY_ENGINE == "mruby"
          Object.prepend(InspectPatch)
          Hash.prepend(HashExt)
          Array.prepend(ArrayPatch)

          Object.include(ObjectPresence)
          Enumerable.include(EnumerablePresence)
          NilClass.include(FalsyPresence)
          FalseClass.include(FalsyPresence)
          String.include(StringPresence)
        end
      end
    end
  end
end
