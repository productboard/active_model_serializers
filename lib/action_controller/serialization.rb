module ActionController
  # Action Controller Serialization
  #
  # Overrides render :json to check if the given object implements +active_model_serializer+
  # as a method. If so, use the returned serializer instead of calling +to_json+ on the object.
  #
  # This module also provides a serialization_scope method that allows you to configure the
  # +serialization_scope+ of the serializer. Most apps will likely set the +serialization_scope+
  # to the current user:
  #
  #    class ApplicationController < ActionController::Base
  #      serialization_scope :current_user
  #    end
  #
  # If you need more complex scope rules, you can simply override the serialization_scope:
  #
  #    class ApplicationController < ActionController::Base
  #      private
  #
  #      def serialization_scope
  #        current_user
  #      end
  #    end
  #
  module Serialization
    extend ActiveSupport::Concern

    include ActionController::Renderers

    included do
      class_attribute :default_serializer_options, default: {}
      class_attribute :_serialization_scope
      self._serialization_scope = :current_user
    end

    def self.camelize(object)
      if object.is_a?(Array)
        object.map { |value| camelize(value) }
      elsif !object.is_a?(String) && object.respond_to?(:as_json)
        object.as_json.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      else
        object
      end
    end

    def get_serializer_options(options)
      default_serializer_options.merge(options || {})
    end

    def serialization_scope
      send(_serialization_scope) if _serialization_scope &&
        respond_to?(_serialization_scope, true)
    end

    [:_render_option_json, :_render_with_renderer_json].each do |renderer_method|
      define_method renderer_method do |resource, options|
        serializer_options = get_serializer_options(options)

        if resource.is_a?(AllSerializer)
          return super(resource.to_json(**serializer_options), options)
        end

        json = ActiveModel::Serializer.build_json(self, resource, get_serializer_options(options))

        if json
          super(json, options)
        elsif serializer_options[:camel_case] && resource.respond_to?(:as_json)
          super(ActionController::Serialization.camelize(resource), options)
        else
          super(resource, options)
        end
      end
    end

    module ClassMethods
      def serialization_scope(scope)
        self._serialization_scope = scope
      end
    end
  end
end
