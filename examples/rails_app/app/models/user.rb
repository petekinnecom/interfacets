class User < ApplicationRecord
  has_one(:address)
  has_many(:phone_numbers, autosave: true)
end
