# frozen_string_literal: true

# require_relative "./test_helper"
# require "ostruct"
# require "interfacets/test"

return
module Interfacets
  class IntegrationTest < Minitest::Test
    class MyFacet < Interfacets::Server::Facet
      config(name: "my-facet")

      find do |_id|
        new(OpenStruct.new(name: "pete"))
      end

      render(:dom) do |c|
        c.input(
          onChange: c.f(:name, ->() { facet.name = "changed" }),
          value: facet.name,
        )

        c.div(onClick: c.f(:submit, ->() { facet.save }))
        c.div(id: facet.saved.to_s)
      end

      id { "id" }
      accessor(:name)
      accessor(:saved, accepted_by: :client) do
        read { !@saved.nil? }
      end

      helpers do
        def save
          submit(:save)
        end
      end

      receive(:save) do |_req|
        @saved = true
      end
    end

    def test_helper
      browser = Interfacets::Test::Session.start(
        facets: [MyFacet], hydrate: "my-facet/1",
      )

      browser.c("dom").trigger(:name)
      assert_equal("changed", browser.c("dom").attr(0, "attributes", "value"))
      assert_equal("false", browser.c("dom").attr(2, "attributes", "id"))
      browser.c("dom").trigger(:submit)
      assert_equal("false", browser.c("dom").attr(2, "attributes", "id"))
      browser.c("interfacets:api").flush_responses
      assert_equal("true", browser.c("dom").attr(2, "attributes", "id"))
    end

    def test_node
      browser = Interfacets::Test::Session.start(
        facets: [MyFacet], hydrate: "my-facet/1",
      )

      assert_equal(
        "pete",
        browser.c("dom").at_css("input").attr("value"),
      )

      browser.c("dom").trigger(:name)
      assert_equal(
        "changed",
        browser.c("dom").at_css("input").attr("value"),
      )

      assert_equal(
        "false",
        browser.c("dom").css("div").last.attr("id"),
      )

      browser.c("dom").trigger(:submit)
      assert_equal(
        "false",
        browser.c("dom").css("div").last.attr("id"),
      )

      browser.c("interfacets:api").flush_responses
      assert_equal(
        "true",
        browser.c("dom").css("div").last.attr("id"),
      )
    end
  end
end
