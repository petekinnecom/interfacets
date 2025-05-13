# frozen_string_literal: true

# rubocop:disable Style/MissingRespondToMissing
original_verbose = $VERBOSE
$VERBOSE = nil

TOP_LEVEL_BINDING = self.binding
DEFAULT_LOG_LEVEL = ENV.fetch("DEFAULT_LOG_LEVEL", "debug").to_sym

class InterfacetsLogger
  class << self
    def main
      @main ||= new(level: DEFAULT_LOG_LEVEL)
    end
  end

  LEVELS = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
    fatal: 4
  }.freeze

  attr_accessor :level
  def initialize(level: :info)
    @level = LEVELS[level] || LEVELS[:info]
  end

  # Meta-program the logging methods
  LEVELS.each do |method_name, level_value|
    define_method(method_name) do |message|
      puts "#{method_name.to_s.upcase}: #{message}" if level_value >= @level
    end
  end
end

$VERBOSE = original_verbose

module Interfacets
  module Client
    module Assets
      class << self
        attr_reader :loader

        def logger
          $asset_logger ||= InterfacetsLogger.main
        end

        def bootstrap(assets)
          @loader = Loader.new(assets)
          Assets.logger.debug("bootstrapping")

          assets
            .fetch("scaffolding")
            .reject { _1.match(/SecureRandom/) } #total hack, bake this into image
            .join("\n")
            .then { TOP_LEVEL_BINDING.eval(_1) }

          Assets.logger.debug("done bootstrapping")

          assets.fetch("fs_map").each_key do |path|
            Assets.logger.debug("planned load: #{path}")
            @loader.load_path(path)
          end
        end
      end

      class Loader
        attr_reader :assets
        def initialize(assets)
          @assets = assets
          @loaded_classes = {}
          @loaded_paths = {}
        end

        def path_loaded?(path)
          @loaded_paths.key?(path)
        end

        def load_path(path)
          return if @loaded_paths.key?(path)

          @loaded_paths[path] = true

          Assets.logger.debug("loading: #{path}")

          TOP_LEVEL_BINDING.eval(fs_map.fetch(path), path)
          Assets.logger.debug("done loading: #{path}")
        end

        def loaded?(klass)
          @loaded_classes.key?(klass)
        end

        def load(klass)
          return if loaded?(klass)

          @loaded_classes[klass] = true

          return if klass.name.nil?

          return unless const_map.key?(klass.name)

          const_map
            .fetch(klass.name)
            .each {
              Assets.logger.debug("klass caused load: #{_1}")
              load_path(_1)
            }
        end

        private

        def scaffolding
          @scaffolding ||= assets.fetch("scaffolding")
        end

        def fs_map
          @fs_map ||= assets.fetch("fs_map")
        end

        def const_map
          @const_map ||= assets.fetch("const_map")
        end
      end

      module AutoloadHook
        def extend_object(o)
          if Assets.loader.loaded?(self)
            super
          else
            Assets.loader.load(self)
            send(:extend_object, o)
          end
        end

        def inherited(mod)
          if Assets.loader.loaded?(self)
            super
          else
            Assets.loader.load(self)
            send(:inherited, mod)
          end
        end

        def append_features(mod)
          if Assets.loader.loaded?(self)
            super
          else
            Assets.loader.load(self)
            send(:append_features, mod)
          end
        end

        # def included(mod)
          # Assets.logger.debug("included: #{self.name} into #{mod.name}")
        #   unless Assets.loader.loaded?(self)
        #     Assets.loader.load(self)
        #     send(:included, mod)
        #   else
        #     super
        #   end
        # end

        # def extended(mod)
          # Assets.logger.debug("extended: #{mod.name}")
        #   unless Assets.loader.loaded?(self)
          #   Assets.logger.debug("loaded: #{self}, now extending")
        #     Assets.loader.load(self)
        #     send(:extended, mod)
        #   else
          #   Assets.logger.debug("already loaded: #{self}, not extending")
        #     super
        #   end
        # end

        # def prepended(mod)
        #   unless Assets.loader.loaded?(self)
        #     Assets.loader.load(self)
        #     send(:prepended, mod)
        #   else
        #     super
        #   end
        # end

        # don't think this is needed
        # def const_missing(const_name)
        #   if Assets.loader.loaded?(self)
        #     super
        #   else
        #     Assets.loader.load(self)
        #     const_get(const_name)
        #   end
        # end

        def method_missing(meth, *a, **p, &)
          if Assets.loader.loaded?(self)
            super
          else
            Assets.loader.load(self)
            send(meth, *a, **p, &)
          end
        end
      end
    end
  end
end
# rubocop:enable Style/MissingRespondToMissing
