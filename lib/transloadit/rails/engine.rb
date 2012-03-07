require 'transloadit/rails'
require 'transloadit/generators'
require 'rails'

class Transloadit
  module Rails
    autoload :ParamsDecoder, 'transloadit/rails/params_decoder'
    autoload :ViewHelper,    'transloadit/rails/view_helper'

    class Engine < ::Rails::Engine
      CONFIG_PATH = 'config/transloadit.yml'

      initializer 'transloadit-rails.action_controller' do |app|
        ActiveSupport.on_load :action_controller do
          helper TransloaditHelper
        end
      end

      initializer 'transloadit-rails.action_view' do |app|
        ActiveSupport.on_load :action_view do
          include Transloadit::Rails::ViewHelper
        end
      end

      initializer 'transloadit.configure' do |app|
        self.class.application = app
      end

      def self.configuration
        path = self.application.root.join(CONFIG_PATH)
        erb  = ERB.new(path.read)

        erb.filename = path.to_s

        YAML.load erb.result
      end

      class << self
        attr_accessor :application

        extend ActiveSupport::Memoizable
        memoize :configuration unless ::Rails.env.development?
      end

      #
      # Returns the Transloadit authentication object.
      #
      def self.transloadit
        Transloadit.new(
          :key      => self.configuration['auth']['key'],
          :secret   => self.configuration['auth']['secret'],
          :duration => self.configuration['auth']['duration']
        )
      end

      #
      # Creates an assembly for the named template.
      #
      
      def self.transloadit_deep_merge(first_hash, second_hash)
        target = dup

        hash.keys.each do |key|
          if hash[key].is_a? Hash and self[key].is_a? Hash
            target[key] = target[key].deep_merge(hash[key])
            next
          end

          target[key] = hash[key]
        end

        target
      end
      
      def self.template(name, options = {})
        template = self.configuration['templates'].try(:fetch, name.to_s)

        self.transloadit.assembly case template
          # this has to be deep_merge. fUck, how can we do that ? 
          # when String then { :template_id => template }.merge(options)
          #      when Hash   then template                    .merge(options)
            
          when String then self.transloadit_deep_merge({ :template_id => template }, options   )
          when Hash   then self.transloadit_deep_merge( template, options )
              
        end
      end

      #
      # Signs a request to the Transloadit API.
      #
      def self.sign(params)
        Transloadit::Request.send :_hmac, self.transloadit.secret, params
      end
    end
  end
end
