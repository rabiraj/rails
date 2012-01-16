module ActionView
  module Helpers
    module Tags
      class TextFieldTag
        include Helpers::ActiveModelInstanceTag, Helpers::TagHelper, Helpers::FormTagHelper

        DEFAULT_FIELD_OPTIONS = { "size" => 30 }

        attr_reader :object

        def initialize(object_name, method_name, template_object, options = {})
          @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
          @template_object = template_object

          @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
          @object = retrieve_object(options.delete(:object))
          @options = options
          @auto_index = retrieve_autoindex(Regexp.last_match.pre_match) if Regexp.last_match
        end

        def render(&block)
          options = @options.stringify_keys
          options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
          options = DEFAULT_FIELD_OPTIONS.merge(options)
          options["type"]  ||= "text"
          options["value"] = options.fetch("value"){ value_before_type_cast(object) }
          options["value"] &&= ERB::Util.html_escape(options["value"])
          add_default_name_and_id(options)
          tag("input", options)
        end

        private

        def value_before_type_cast(object)
          unless object.nil?
            object.respond_to?(@method_name + "_before_type_cast") ?
            object.send(@method_name + "_before_type_cast") :
            object.send(@method_name)
          end
        end

        def retrieve_object(object)
          if object
            object
          elsif @template_object.instance_variable_defined?("@#{@object_name}")
            @template_object.instance_variable_get("@#{@object_name}")
          end
        rescue NameError
          # As @object_name may contain the nested syntax (item[subobject]) we need to fallback to nil.
          nil
        end

        def retrieve_autoindex(pre_match)
          object = self.object || @template_object.instance_variable_get("@#{pre_match}")
          if object && object.respond_to?(:to_param)
            object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end

        def add_default_name_and_id_for_value(tag_value, options)
          unless tag_value.nil?
            pretty_tag_value = tag_value.to_s.gsub(/\s/, "_").gsub(/[^-\w]/, "").downcase
            specified_id = options["id"]
            add_default_name_and_id(options)
            options["id"] += "_#{pretty_tag_value}" if specified_id.blank? && options["id"].present?
          else
            add_default_name_and_id(options)
          end
        end

        def add_default_name_and_id(options)
          if options.has_key?("index")
            options["name"] ||= tag_name_with_index(options["index"])
            options["id"] = options.fetch("id"){ tag_id_with_index(options["index"]) }
            options.delete("index")
          elsif defined?(@auto_index)
            options["name"] ||= tag_name_with_index(@auto_index)
            options["id"] = options.fetch("id"){ tag_id_with_index(@auto_index) }
          else
            options["name"] ||= tag_name + (options['multiple'] ? '[]' : '')
            options["id"] = options.fetch("id"){ tag_id }
          end
          options["id"] = [options.delete('namespace'), options["id"]].compact.join("_").presence
        end

        def tag_name
          "#{@object_name}[#{sanitized_method_name}]"
        end

        def tag_name_with_index(index)
          "#{@object_name}[#{index}][#{sanitized_method_name}]"
        end

        def tag_id
          "#{sanitized_object_name}_#{sanitized_method_name}"
        end

        def tag_id_with_index(index)
          "#{sanitized_object_name}_#{index}_#{sanitized_method_name}"
        end

        def sanitized_object_name
          @sanitized_object_name ||= @object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
        end

        def sanitized_method_name
          @sanitized_method_name ||= @method_name.sub(/\?$/,"")
        end
      end
    end
  end
end
