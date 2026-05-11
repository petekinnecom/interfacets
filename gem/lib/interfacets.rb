# frozen_string_literal: true

require "zeitwerk"
require "active_support/concern"

module Interfacets
  class << self
    def reload
      loader.reload
    end

    def loader
      @loader ||= (
        Zeitwerk::Loader
          .for_gem
          .tap { _1.ignore("#{__dir__}/interfacets/mruby") }
          .tap { _1.ignore("#{__dir__}/interfacets/client/utils") }
          .tap { _1.enable_reloading if enable_reloading? }
          .tap(&:setup)
      )
    end

    def enable_reloading?
      $interfacets_dev_mode
    end
  end

  class Error < StandardError; end
  class ValidationError < Error; end
  class MissingComponentContractError < Error; end
end

unless Interfacets.enable_reloading?
  Interfacets.loader
end
