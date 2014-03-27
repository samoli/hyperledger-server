class CurrenciesController < ApplicationController
  
  respond_to :json
  
  def show
    respond_with Currency.find_by_name(params[:name])
  end

  def index
    respond_with Currency.all
  end

  def create
    currency = Currency.create(currency_params)
    respond_with currency
  end
  
private
  
  def currency_params
    params.permit(:public_key, :name, :url)
  end
  
end
