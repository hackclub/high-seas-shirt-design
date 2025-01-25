require 'norairrecord'

Norairrecord.api_key = ENV["AIRTABLE_PAT"]
Norairrecord.base_url = ENV["AIRTABLE_ENDPOINT_URL"] if ENV['AIRTABLE_ENDPOINT_URL']

class Person < Norairrecord::Table
  self.base_key = "appTeNFYcUiYfGcR6"
  self.table_name = 'tblfTzYVqvDJlIYUB' # 'people'

  has_many :ships, class: 'Ship', column: 'ships'

  def nice_full_name
    "#{self["first_name"].first} #{self["last_name"].first}"
  end
end

class Ship < Norairrecord::Table
  self.base_key = "appTeNFYcUiYfGcR6"
  self.table_name = 'tblHeGZNG00d4GBBV' # 'ships'

  has_one :entrant, class: 'Person', column: 'entrant'
end

class Tavern < Norairrecord::Table
  self.base_key = "appTeNFYcUiYfGcR6"
  self.table_name = 'tbl6Sp1jh3ytwmcIo' # 'taverns'

  has_one :primary_organizer, class: 'Person', column: 'primary_organizer'
  has_many :organizers, class: 'Person', column: 'organizers'
  has_many :attendees, class: 'Person', column: 'attendees'

  def people
    @people ||= [primary_organizer, *organizers, *attendees].compact.uniq { |person| person.id }
  end
end