require "ostruct"

module Facets
  module Users
    class Index < ApplicationFacet
      view do |list|
        render(:dom) do |d|
          d.h1("Users")

          d.a(
            "Create New",
            href: "/ui/users/new"
          )

          d.ul do
            list.users.each do |user|
              d.li do
                d.a(
                  user.name,
                  href: user.url
                )
              end
            end
          end


        end
      end

      client do
      end

      shared do
        collection(:users) do
          accessor(:id, accepted_by: :client)
          accessor(:name, accepted_by: :client)

          def url
            "/ui/users/#{id}"
          end
        end
      end

      find do |id, query:|
        build(self, {users: User.all.to_a})
      end

      server do
      end
    end
  end
end
