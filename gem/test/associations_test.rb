# frozen_string_literal: true

# require_relative "./test_helper"
# require "ostruct"
# require "interfacets/test"
return

module Interfacets
  class AssociationsTest < Minitest::Test
    City = Struct.new(:name, :state)
    State = Struct.new(:name)

    module CityRepo
      class << self
        attr_accessor :city
      end
    end

    module CityFacet
      extend ActiveSupport::Concern

      included do
        config(name: "city")

        server_entity do
          find do |_id|
            new(CityRepo.city)
          end
        end

        id { record.name }

        render("dom") do |c|
          c.div(
            value: facet.state.name,
            update: c.f(
              :update,
              -> { facet.state.name = "NewOregon" },
            ),
          )
        end
      end
    end

    def test_explicit_and_nested
      city_facet =
        Class.new(Interfacets::Server::Facet) do
          include CityFacet

          association(:state) do
            read { record.state }

            nested do
              id { record.name }

              accessor(:name)
            end
          end
        end

      # server tests
      city = City.new("Portland", State.new("Oregon"))
      facet = city_facet.new(city)
      assert_equal("Oregon", facet.state.name)
      facet.state.name = "NewOregon"
      assert_equal("NewOregon", facet.state.name)
      assert_equal("NewOregon", city.state.name)

      # client tests
      CityRepo.city = City.new("Portland", State.new("Oregon"))
      browser = Interfacets::Test::Session.start(
        facets: [city_facet], hydrate: "city/1",
      )
      assert_equal(
        "Oregon",
        browser.c("dom").at_css("div").attr("value"),
      )
      browser.c("dom").trigger(:update)
      assert_equal(
        "NewOregon",
        browser.c("dom").at_css("div").attr("value"),
      )
    end

    def test_implicit_read
      city_facet =
        Class.new(Interfacets::Server::Facet) do
          include CityFacet

          association(:state) do
            nested do
              id { record.name }

              accessor(:name)
            end
          end
        end

      # server tests
      city = City.new("Portland", State.new("Oregon"))
      facet = city_facet.new(city)
      assert_equal("Oregon", facet.state.name)
    end

    def test_non_nested_class
      state_facet =
        Class.new(Interfacets::Server::Facet) do
          config(name: "state")
          id { record.name }
          accessor(:name)
        end

      city_facet =
        Class.new(Interfacets::Server::Facet) do
          include CityFacet

          association(:state, state_facet)
        end

      # server tests
      city = City.new("Portland", State.new("Oregon"))
      facet = city_facet.new(city)
      assert_equal("Oregon", facet.state.name)
    end

    def test_can_render
      state_facet =
        Class.new(Interfacets::Server::Facet) do
          config(name: "state")
          id { record.name }
          accessor(:name)

          render("dom") do |c|
            c.div(
              value: facet.name,
              update: c.f(
                :update,
                -> { facet.name = "NewOregon" },
              ),
            )
          end
        end

      city_facet =
        Class.new(Interfacets::Server::Facet) do
          include CityFacet

          render("dom") do |c|
            facet.state.render("dom", c)
          end

          association(:state, state_facet)
        end

      # client tests
      CityRepo.city = City.new("Portland", State.new("Oregon"))
      browser = Interfacets::Test::Session.start(
        facets: [city_facet, state_facet], hydrate: "city/1",
      )
      assert_equal(
        "Oregon",
        browser.c("dom").at_css("div").attr("value"),
      )
      browser.c("dom").trigger(:update)
      assert_equal(
        "NewOregon",
        browser.c("dom").at_css("div").attr("value"),
      )
    end

    def test_can_bind_attribute
      state_facet =
        Class.new(Interfacets::Server::Facet) do
          config(
            name: "state",
            binds: [:some_var, :city_name],
          )
          id { record.name }
          accessor(:name)

          render("dom") do |c|
            c.d1(
              value: facet.some_var,
              update: c.f(
                :update_some_var,
                -> { facet.some_var = "New#{facet.some_var}" },
              ),
            )
            c.d2(
              value: facet.city_name,
              update: c.f(
                :update_city_name,
                -> { facet.city_name = "New#{facet.city_name}" },
              ),
            )
          end
        end

      city_facet =
        Class.new(Interfacets::Server::Facet) do
          include CityFacet

          render("dom") do |c|
            facet.state.render("dom", c)

            c.CityName(value: facet.name)
          end

          accessor(:name)

          association(
            :state,
            state_facet,
            binds: [
              :some_var,
              { city_name: :name },
            ],
          )

          helpers do
            attr_writer :some_var
            def some_var
              @some_var ||= "some_var"
            end
          end
        end

      # client tests
      CityRepo.city = City.new("Portland", State.new("Oregon"))
      browser = Interfacets::Test::Session.start(
        facets: [city_facet, state_facet], hydrate: "city/1",
      )
      assert_equal(
        "some_var",
        browser.c("dom").at_css("d1").attr("value"),
      )
      browser.c("dom").trigger(:update_some_var)
      assert_equal(
        "Newsome_var",
        browser.c("dom").at_css("d1").attr("value"),
      )

      assert_equal(
        "Portland",
        browser.c("dom").at_css("d2").attr("value"),
      )
      browser.c("dom").trigger(:update_city_name)
      assert_equal(
        "NewPortland",
        browser.c("dom").at_css("d2").attr("value"),
      )
      assert_equal(
        "NewPortland",
        browser.c("dom").at_css("CityName").attr("value"),
      )
    end
  end
end
