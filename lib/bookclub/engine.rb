# frozen_string_literal: true

module Bookclub
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Bookclub
    config.autoload_paths << File.join(config.root, 'lib')
  end
end
