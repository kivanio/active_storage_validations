# frozen_string_literal: true

# == Schema Information
#
# Table name: content_type_validator_check_validity_invalid_content_type_ins
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ContentType::Validator::CheckValidityInvalidContentTypeIn < ApplicationRecord
  has_one_attached :invalid
  validates :invalid, content_type: ["xxx/invalid1", "xxx/invalid2"]
end
