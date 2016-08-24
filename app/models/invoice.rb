class Invoice < ApplicationRecord
  geocoded_by :address_start, latitude: :latitude_start,
    longitude: :longitude_start
  after_validation :custom_reverse_geocode, :custom_geocode, :geocode

  has_many :user_invoices, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :invoice_histories, dependent: :destroy
  has_many :all_shipper, through: :user_invoices, source: :user

  belongs_to :user

  ATTRIBUTES_PARAMS = [:name, :address_start, :address_finish, :delivery_time,
    :distance, :description, :price, :shipping_price, :status, :weight,
    :customer_name, :customer_number, :latitude_start, :longitude_start,
    :latitude_finish, :longitude_finish]

  INVOICE_PARAMS = Set.new ["price", "shipping_price", "distance", "weight",
    "latitude", "longitude", "radius"]

  USER_PARAMS = Set.new ["latitude", "longitude", "distance"]

  enum status: [:init, :waiting, :shipping, :shipped, :finished, :cancel]

  scope :filter_by, -> column, min, max{
    where "#{column} BETWEEN ? AND ?", min, max}

  class << self
    def filtering_column params
      params.slice :price, :shipping_price, :distance, :weight
    end

    def search params = {}
      if params[:user].present?
        invoices = Invoice.near [params[:user][:latitude],
        params[:user][:longitude]], params[:user][:distance] if
        params[:user][:latitude] && params[:user][:longitude] &&
        params[:user][:distance]

        invoices = Hash.new unless params[:user].keys.to_set.subset? USER_PARAMS

      elsif params[:invoice].present?
        invoices = Invoice.all

        invoices = Invoice.near [params[:invoice][:latitude],
          params[:invoice][:longitude]], params[:invoice][:radius] if
          params[:invoice][:latitude] && params[:invoice][:longitude] &&
          params[:invoice][:radius]

        Invoice.filtering_column(params[:invoice]).each do |key, value|
          invoices = invoices.filter_by key, value[:min], value[:max] if
            value[:min].present? && value[:max].present?
        end
        invoices = Hash.new unless params[:invoice].keys.to_set.subset? INVOICE_PARAMS
      end
      invoices.init if invoices.any?
      invoices
    end
  end

  private
  def custom_geocode
    self.latitude_start, self.longitude_start = Geocoder.coordinates address_start
    self.latitude_finish, self.longitude_finish = Geocoder.coordinates address_finish
  end

  def custom_reverse_geocode
    self.address_start = Geocoder.search([latitude_start, longitude_start])
      .first.data["formatted_address"] if
      latitude_start.present? && longitude_start.present?
    self.address_finish = Geocoder.search([latitude_finish, longitude_finish])
      .first.data["formatted_address"] if
      latitude_finish.present? && longitude_finish.present?
  end
end
