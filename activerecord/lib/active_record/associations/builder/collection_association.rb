# This class is inherited by the has_many and has_many_and_belongs_to_many association classes 

require 'active_record/associations'

module ActiveRecord::Associations::Builder
  class CollectionAssociation < Association #:nodoc:

    CALLBACKS = [:before_add, :after_add, :before_remove, :after_remove]

    def valid_options
      super + [:table_name, :before_add,
               :after_add, :before_remove, :after_remove, :extend]
    end

    attr_reader :block_extension, :extension_module

    def initialize(*args, &extension)
      super(*args)
      @block_extension = extension
    end

    def build
      wrap_block_extension
      reflection = super
      CALLBACKS.each { |callback_name| define_callback(callback_name) }
      reflection
    end

    def writable?
      true
    end

    def wrap_block_extension
      if block_extension
        @extension_module = mod = Module.new(&block_extension)
        silence_warnings do
          model.parent.const_set(extension_module_name, mod)
        end

        prev_scope = @scope

        if prev_scope
          @scope = proc { |owner| instance_exec(owner, &prev_scope).extending(mod) }
        else
          @scope = proc { extending(mod) }
        end
      end
    end

    def extension_module_name
      @extension_module_name ||= "#{model.name.demodulize}#{name.to_s.camelize}AssociationExtension"
    end

    def define_callback(callback_name)
      full_callback_name = "#{callback_name}_for_#{name}"

      # TODO : why do i need method_defined? I think its because of the inheritance chain
      model.class_attribute full_callback_name unless model.method_defined?(full_callback_name)
      callbacks = Array(options[callback_name.to_sym]).map do |callback|
        case callback
        when Symbol
          ->(method, owner, record) { owner.send(callback, record) }
        when Proc
          ->(method, owner, record) { callback.call(owner, record) }
        else
          ->(method, owner, record) { callback.send(method, owner, record) }
        end
      end
      model.send "#{full_callback_name}=", callbacks
    end

    # Defines the setter and getter methods for the collection_singular_ids.

    def define_readers(mixin)
      super

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name.to_s.singularize}_ids
          association(:#{name}).ids_reader
        end
      CODE
    end

    def define_writers(mixin)
      super

      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name.to_s.singularize}_ids=(ids)
          association(:#{name}).ids_writer(ids)
        end
      CODE
    end
  end
end
