# frozen_string_literal: true

require_relative 'shared/asv_active_storageable'
require_relative 'shared/asv_analyzable'
require_relative 'shared/asv_attachable'
require_relative 'shared/asv_errorable'
require_relative 'shared/asv_optionable'
require_relative 'shared/asv_symbolizable'

module ActiveStorageValidations
  class DimensionValidator < ActiveModel::EachValidator # :nodoc
    include ASVActiveStorageable
    include ASVAnalyzable
    include ASVAttachable
    include ASVErrorable
    include ASVOptionable
    include ASVSymbolizable

    AVAILABLE_CHECKS = %i[width height min max].freeze
    ERROR_TYPES = %i[
      dimension_min_not_included_in
      dimension_max_not_included_in
      dimension_width_not_included_in
      dimension_height_not_included_in
      dimension_width_not_greater_than_or_equal_to
      dimension_height_not_greater_than_or_equal_to
      dimension_width_not_less_than_or_equal_to
      dimension_height_not_less_than_or_equal_to
      dimension_width_not_equal_to
      dimension_height_not_equal_to
      media_metadata_missing
    ].freeze
    METADATA_KEYS = %i[width height].freeze

    def check_validity!
      unless AVAILABLE_CHECKS.any? { |argument| options.key?(argument) }
        raise ArgumentError, 'You must pass either :width, :height, :min or :max to the validator'
      end
    end

    def validate_each(record, attribute, _value)
      return if no_attachments?(record, attribute)

      validate_changed_files_from_metadata(record, attribute, METADATA_KEYS)
    end

    private

    def is_valid?(record, attribute, file, metadata)
      flat_options = process_options(record)
      errors_options = initialize_error_options(options, file)

      # Validation fails unless file metadata contains valid width and height.
      if metadata[:width].to_i <= 0 || metadata[:height].to_i <= 0
        add_error(record, attribute, :media_metadata_missing, **errors_options)
        return false
      end

      # Validation based on checks :min and :max (:min, :max has higher priority to :width, :height).
      if flat_options[:min] || flat_options[:max]
        if flat_options[:min] && (
          (flat_options[:width][:min] && metadata[:width] < flat_options[:width][:min]) ||
          (flat_options[:height][:min] && metadata[:height] < flat_options[:height][:min])
          )
          errors_options[:width] = flat_options[:width][:min]
          errors_options[:height] = flat_options[:height][:min]

          add_error(record, attribute, :dimension_min_not_included_in, **errors_options)
          return false
        end
        if flat_options[:max] && (
          (flat_options[:width][:max] && metadata[:width] > flat_options[:width][:max]) ||
          (flat_options[:height][:max] && metadata[:height] > flat_options[:height][:max])
          )
          errors_options[:width] = flat_options[:width][:max]
          errors_options[:height] = flat_options[:height][:max]

          add_error(record, attribute, :dimension_max_not_included_in, **errors_options)
          return false
        end

      # Validation based on checks :width and :height.
      else
        width_or_height_invalid = false

        [:width, :height].each do |length|
          next unless flat_options[length]
          if flat_options[length].is_a?(Hash)
            if flat_options[length][:in] && (metadata[length] < flat_options[length][:min] || metadata[length] > flat_options[length][:max])
              error_type = :"dimension_#{length}_not_included_in"
              errors_options[:min] = flat_options[length][:min]
              errors_options[:max] = flat_options[length][:max]

              add_error(record, attribute, error_type, **errors_options)
              width_or_height_invalid = true
            else
              if flat_options[length][:min] && metadata[length] < flat_options[length][:min]
                error_type = :"dimension_#{length}_not_greater_than_or_equal_to"
                errors_options[:length] = flat_options[length][:min]

                add_error(record, attribute, error_type, **errors_options)
                width_or_height_invalid = true
              elsif flat_options[length][:max] && metadata[length] > flat_options[length][:max]
                error_type = :"dimension_#{length}_not_less_than_or_equal_to"
                errors_options[:length] = flat_options[length][:max]

                add_error(record, attribute, error_type, **errors_options)
                width_or_height_invalid = true
              end
            end
          else
            if metadata[length] != flat_options[length]
              error_type = :"dimension_#{length}_not_equal_to"
              errors_options[:length] = flat_options[length]

              add_error(record, attribute, error_type, **errors_options)
              width_or_height_invalid = true
            end
          end
        end

        return false if width_or_height_invalid
      end

      true # valid file
    end

    def process_options(record)
      flat_options = set_flat_options(record)

      [:width, :height].each do |length|
        if flat_options[length] and flat_options[length].is_a?(Hash)
          if (range = flat_options[length][:in])
            raise ArgumentError, ":in must be a Range" unless range.is_a?(Range)
            flat_options[length][:min], flat_options[length][:max] = range.min, range.max
          end
        end
      end
      [:min, :max].each do |dim|
        if (range = flat_options[dim])
          raise ArgumentError, ":#{dim} must be a Range (width..height)" unless range.is_a?(Range)
          flat_options[:width] = { dim => range.first }
          flat_options[:height] = { dim => range.last }
        end
      end

      flat_options
    end
  end
end
