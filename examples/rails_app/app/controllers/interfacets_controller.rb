class InterfacetsController < ApplicationController
  def show
    @facet_json = facet.render

    respond_to do |req|
      req.html { }
      req.json { render(json: @facet_json) }
    end
  end

  def update
    payload = params.dig(:event, :payload).to_unsafe_hash

    render(json: facet.handle(payload), status: 201)
  end

  private

  def facet
    @facet ||= (
      Rails
        .configuration
        .x
        .interfacets
        .router
        .call(params.fetch(:facet_path), query: query_params)
    )
  end

  def query_params
    params
      .except(
        :facet_path,
        :controller,
        :action,
        :format
      )
      .to_unsafe_h
  end
end
