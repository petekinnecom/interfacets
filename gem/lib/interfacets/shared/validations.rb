# frozen_string_literal: true

module Interfacets
  module Shared
    module Validations
      extend ActiveSupport::Concern

      class Errors
        include Enumerable

        def initialize
          @errors = Hash.new { |h, k| h[k] = [] }
        end

        def add(k, v)
          @errors[k.to_sym] << v
        end

        def clear
          @errors.clear
        end

        def [](k)
          @errors[k]
        end

        def each(...)
          @errors.each(...)
        end

        def empty?
          @errors.all? { _2.empty? }
        end
      end

      included do
        def self.validators
          @validators ||= []
        end

        def self.validate(&block)
          raise(ArgumentError.new("block required")) unless block_given?

          validators << block
        end

        def errors
          @errors ||= Errors.new
        end

        def errors_if_changed(attr)
          errors[attr].any? ? errors[attr] : nil
        end

        def valid?
          errors.empty?
        end

        def validate
          @errors = Errors.new
          self.class.validators.each do |block|
            instance_exec(&block)
          end
        end

        # on_change do |attr, _old_val, _new_val|
        #   reset_validations
        # end
      end

      class_methods do
      end
    end
  end
end
