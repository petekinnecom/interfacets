# frozen_string_literal: true

module Interfacets
  module Client
    module Channels
      module Base
        extend ActiveSupport::Concern

        attr_reader :id

        def initialize(id:)
          @id = id
        end

        def type
          self.class.type
        end

        class_methods do
          def type(str = nil)
            @type = str if str
            @type
          end
        end
      end
    end
  end
end
