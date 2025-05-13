# frozen_string_literal: true

# require_relative "./test_helper"
# require "ostruct"
# require "interfacets/test"
return

module Interfacets
  class CollectionsTest < Minitest::Test
    State = Struct.new(:name, :cities)
    City = Struct.new(:name)

    module StateRepo
      class << self
        attr_accessor :state, :saved
      end
    end

    module StateFacet
      extend ActiveSupport::Concern

      included do
        config(name: "state")

        find do |_id|
          new(StateRepo.state)
        end

        id { record.name }

        render("dom") do |c|
          facet.cities.each_with_index do |city, i|
            c.div(
              value: city.name,
              update: c.f(
                "update-#{i}",
                -> { city.name = "New#{city.name}" },
              ),
            )
          end

          c.button(
            update: c.f(
              :add,
              -> { facet.cities << facet.build(:cities, name: "added") },
            ),
          )

          c.button(
            update: c.f(
              :remove,
              -> { facet.cities.pop },
            ),
          )

          c.button(onClick: c.f(:submit, ->() { facet.save }))
        end

        helpers do
          def save
            submit(:save)
          end
        end

        receive(:save) do |_req|
          StateRepo.saved = record
        end
      end
    end

    def test_explicit_and_nested
      state_facet =
        Class.new(Interfacets::Server::Facet) do
          include StateFacet

          collection(:cities) do
            each { record.cities }
            build { record.cities << City.new }
            reconcile do |add:, destroy:|
              record.cities += add
              destroy.each do
                record.cities.delete(_1)
              end
            end

            nested do
              id { record.name }

              accessor(:name)
            end
          end
        end

      # server tests
      state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      facet = state_facet.new(state)
      assert_equal(["Portland", "Salem"], facet.cities.map(&:name))
      facet.cities.last.name = "NewSalem"
      assert_equal("NewSalem", facet.cities.last.name)
      assert_equal("NewSalem", state.cities.last.name)

      # client tests
      StateRepo.state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      browser = Interfacets::Test::Session.start(
        facets: [state_facet], hydrate: "state/1",
      )
      assert_equal(
        ["Portland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("update-0")
      assert_equal(
        ["NewPortland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("update-1")
      assert_equal(
        ["NewPortland", "NewSalem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("add")
      assert_equal(
        ["NewPortland", "NewSalem", "added"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("remove")
      assert_equal(
        ["NewPortland", "NewSalem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )
      browser.c("dom").trigger("submit")
      assert_equal(["NewPortland", "NewSalem"], StateRepo.saved.cities.map(&:name))
    end

    def test_implicit_read
      state_facet =
        Class.new(Interfacets::Server::Facet) do
          include StateFacet

          collection(:cities) do
            build { City.new }

            nested do
              id { record.name }

              accessor(:name)
            end
          end
        end

      # server tests
      state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      facet = state_facet.new(state)
      assert_equal(["Portland", "Salem"], facet.cities.map(&:name))

      # client tests
      StateRepo.state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      browser = Interfacets::Test::Session.start(
        facets: [state_facet], hydrate: "state/1",
      )
      assert_equal(
        ["Portland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("update-0")
      assert_equal(
        ["NewPortland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("update-1")
      assert_equal(
        ["NewPortland", "NewSalem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )
      browser.c("dom").trigger("remove")
      assert_equal(
        ["NewPortland"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("add")
      assert_equal(
        ["NewPortland", "added"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("submit")
      assert_equal(["NewPortland", "added"], StateRepo.saved.cities.map(&:name))
    end

    def test_non_nested_class
      city_facet =
        Class.new(Interfacets::Server::Facet) do
          config(name: "city")

          id { record.name }

          accessor(:name)
        end

      state_facet =
        Class.new(Interfacets::Server::Facet) do
          include StateFacet
          collection(:cities, city_facet) do
            build { City.new }
          end
        end

      # server tests
      state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      facet = state_facet.new(state)
      assert_equal(["Portland", "Salem"], facet.cities.map(&:name))

      # client tests
      StateRepo.state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      browser = Interfacets::Test::Session.start(
        facets: [state_facet, city_facet], hydrate: "state/1",
      )
      assert_equal(
        ["Portland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("update-0")
      assert_equal(
        ["NewPortland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("update-1")
      assert_equal(
        ["NewPortland", "NewSalem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )
      browser.c("dom").trigger("remove")
      assert_equal(
        ["NewPortland"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("add")
      assert_equal(
        ["NewPortland", "added"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger("submit")
      assert_equal(["NewPortland", "added"], StateRepo.saved.cities.map(&:name))
    end

    def test_can_render
      city_facet =
        Class.new(Interfacets::Server::Facet) do
          config(name: "city")
          id { record.name }
          accessor(:name)

          render(:dom) do |c|
            c.div(
              value: facet.name,
              update: c.f(
                { update: facet.name },
                -> { facet.name = "New#{facet.name}" },
              ),
            )
          end
        end

      state_facet =
        Class.new(Interfacets::Server::Facet) do
          include StateFacet

          render("dom") do |c|
            facet.cities.map { _1.render("dom", c) }
          end

          collection(:cities, city_facet) do
            build { City.new }
          end
        end

      # client tests
      StateRepo.state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      browser = Interfacets::Test::Session.start(
        facets: [state_facet, city_facet], hydrate: "state/1",
      )
      assert_equal(
        ["Portland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger({ update: "Portland" })
      assert_equal(
        ["NewPortland", "Salem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )

      browser.c("dom").trigger({ update: "Salem" })
      assert_equal(
        ["NewPortland", "NewSalem"],
        browser.c("dom").css("div").map { _1.attr("value") },
      )
    end

    def test_can_bind_attribute
      city_facet =
        Class.new(Interfacets::Server::Facet) do
          config(
            name: "city",
            binds: [:some_var, :state_name],
          )

          id { record.name }
          accessor(:name)

          render("dom") do |c|
            c.d1(
              value: facet.some_var,
              update: c.f(
                { update_some_var: facet.name },
                -> { facet.some_var = "New#{facet.some_var}" },
              ),
            )
            c.d2(
              value: facet.state_name,
              update: c.f(
                { update_state_name: facet.name },
                -> { facet.state_name = "New#{facet.state_name}" },
              ),
            )
          end
        end

      state_facet =
        Class.new(Interfacets::Server::Facet) do
          include StateFacet

          render("dom") do |c|
            facet.cities.map { _1.render("dom", c) }
            c.StateName(value: facet.name)
          end

          collection(
            :cities,
            city_facet,
            binds: [:some_var, { state_name: :name }],
          ) do
            build { City.new }
          end

          accessor(:name)

          helpers do
            attr_writer :some_var
            def some_var
              @some_var ||= "some_var"
            end
          end
        end

      # client tests
      StateRepo.state = State.new("Oregon", [City.new("Portland"), City.new("Salem")])
      browser = Interfacets::Test::Session.start(
        facets: [state_facet, city_facet], hydrate: "state/1",
      )
      assert_equal(
        ["some_var", "some_var"],
        browser.c("dom").css("d1").map { _1.attr("value") },
      )
      assert_equal(
        ["Oregon", "Oregon"],
        browser.c("dom").css("d2").map { _1.attr("value") },
      )

      browser.c("dom").trigger({ update_some_var: "Portland" })
      assert_equal(
        ["Newsome_var", "Newsome_var"],
        browser.c("dom").css("d1").map { _1.attr("value") },
      )
      assert_equal(
        ["Oregon", "Oregon"],
        browser.c("dom").css("d2").map { _1.attr("value") },
      )

      browser.c("dom").trigger({ update_state_name: "Salem" })
      assert_equal(
        ["Newsome_var", "Newsome_var"],
        browser.c("dom").css("d1").map { _1.attr("value") },
      )
      assert_equal(
        ["NewOregon", "NewOregon"],
        browser.c("dom").css("d2").map { _1.attr("value") },
      )
    end
  end
end
