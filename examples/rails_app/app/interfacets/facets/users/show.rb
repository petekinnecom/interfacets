module Facets
  module Users
    class Show < ApplicationFacet
      view do |user|
        render(:url) do |url|
          url.path(user.api_path)
        end

        render(:dom) do |d|
          d.p("User ID: #{user.id.inspect}")

          d.div do
            d.label("Name:")
            d.input(
              id: "user-name",
              value: user.name,
              onChange: ->(val) { user.name = val },

            )
          end

          d.div do
            if user.address
              d.label("Address.city:")
              d.input(
                id: "address-city",
                value: user.address.city,
                onChange: ->(value) { user.address.city = value},
              )

              d.button(
                "Delete Address",
                onClick: -> { user.address = nil }
              )
            else
              d.button(
                "Add Address",
                onClick: -> { user.association(:address).build }
              )
            end
          end

          user.phone_numbers.each_with_index do |phone_number, i|
            d.div do
              d.label("Phone number: #{i+1}")
              d.input(
                value: phone_number.value,
                onChange: ->(val) { phone_number.value = val }
              )
              d.button(
                "Remove Phone Number",
                onClick: -> { user.phone_numbers.delete(phone_number) }
              )
            end
          end

          d.button(
            "Add Phone Number",
            onClick: -> { user.association(:phone_numbers).build }
          )

          d.div do
            d.button(
              "Save",
              onClick: -> { user.save }
            )
          end
        end
      end

      client do
      end

      shared do
        accessor(:id, accepted_by: :client)
        accessor(:name)

        reference(:address) do
          accessor(:id, accepted_by: :client)
          accessor(:city)
        end

        collection(:phone_numbers) do
          accessor(:id, accepted_by: :client)
          accessor(:value)
        end

        server_action(:save)
      end

      find do |id, query:|
        user = (
          if id == "new"
            User.new
          else
            User.find(id)
          end
        )

        build(self, user)
      end

      server do
      end
    end
  end
end
