require 'printfulrb'
require 'countries'
require_relative './models'

SIZE_MAPPING = {
  'Small' => 17648,
  'Medium' => 17649,
  'Large' => 17650,
  'XL' => 17651,
  'XXL' => 17652
}

def size_to_variant(size)
  SIZE_MAPPING[size] || SIZE_MAPPING['Medium']
end

def generate_gift_info(tavern)
  {
    subject: "hey! thanks for organizing Mystic Tavern #{tavern['city']}!",
    message: "good luck from all of us at Hack Club HQ <3333333"
  }
end

def generate_packing_slip_info(tavern)
  # TODO: make this say something tavern-specific
  # would be cool to have message along the lines of 'holy shit these shirts total <n> ships!!'
  {
    email: 'nora+tavern@hackclub.com',
    phone: '+1 (802) 266-0668',
    message: 'yarr har fiddle-dee-dee',
    logo_url: 'https://cloud-6zfowgva5-hack-club-bot.vercel.app/0highseaslogo.png',
  }
end

def generate_shirt_items(person)
  variant_id = size_to_variant(person['shirt_size'])
  shirt_designs = person['shirt_design']&.map { |img| img['url'] }
  shirt_designs&.map.with_index do |url, index|
    {
      variant_id:,
      quantity: 1,
      retail_price: '$5',
      name: "#{person['first_name'].first}'s shirt!#{"#{index + 1} of #{shirt_designs.length}" unless shirt_designs.length == 1}",
      files: [
        {
          # id: 788034101, # High Seas logo
          url: "https://cloud-ppa19gvtr-hack-club-bot.vercel.app/00.png",
          type: 'front',
          "position": {
            # <lol, lmao>
            left: 0,
            top: 100,
            areaWidth: 1800,
            areaHeight: 2400,
            width: 1800,
            height: 2400,
            limit_to_print_area: false
            # </lol, lmao>
          },
        },
        {
          url:, # QR codes
          type: 'back',
          position: {
            areaWidth: 1800,
            areaHeight: 2400,
            width: 1752,
            height: 2400,
            top: 0,
            left: 0,
            limit_to_print_area: false
          }
        }
      ]
    }
  end
end

class MockTavern
  FIELDS = {
    shirt_delivery_address: true,
    addr_first_name: 'Nora',
    addr_last_name: 'Tavern',
    addr_line_1: '15 Falls Rd',
    addr_city: 'Shelburne',
    addr_state: 'Vermont',
    addr_zip: '05602',
    addr_country: 'United States',
    addr_email: 'nora+printful@hackclub.com',
    city: 'Shelburne'
  }

  def initialize
    @people = Person.where "slack_id='U06QK6AG3RD'"
    # @people = [
    #   {
    #       'first_name' => ['Nora'],
    #       'shirt_size'=>'Medium',
    #       'shirt_design' => [{'url'=> 'https://v5.airtableusercontent.com/v3/u/37/37/1737770400000/tqagBefBWQLl9IfzeUtQDA/AlhvR9kgadO944YFrGTAuE6H0W9o4o9GqnMDDrW-SkyM6LA7SB_f2Lh-T7uAcY_aUQHGjW2ENhD5TVOudN9JrH5bgLlLBbU0976fFujrSl4fqtb1lhDg2DWLSa6Sw895Wbw_eEX4nGiBBYNKyFnEEg/odyIf49aKMFPA1Pg9nvOwYYP66jRwOQj85ex_ekS9Ak'}]
    #   }
    # ]
  end

  attr_accessor :people

  def id
    "recFAKE#{rand(10000)}#{rand(10000)}"
  end

  def [](key)
    FIELDS[key.to_sym]
  end
end

class WhatCountryError < StandardError; end

def generate_order(tavern, expedited: false)
  raise "no address?" unless tavern['shirt_delivery_address']
  country_and_state(tavern['addr_country'], tavern['addr_state']) => { country_code:, state_code: }
  items = tavern.people.flat_map { |person| generate_shirt_items(person) }.compact
  {
    external_id: tavern.id.gsub('rec', 'Tavern.'),
    shipping: expedited ? 'PRINTFUL_FAST' : 'STANDARD',
    items:,
    retail_costs: {
      currency: 'USD',
      subtotal: items.length * 5
    },
    gift: generate_gift_info(tavern),
    packing_slip: generate_packing_slip_info(tavern),
    recipient: {
      name: "#{tavern['addr_first_name']} #{tavern['addr_last_name']}",
      address1: tavern['addr_line_1'],
      address2: tavern['addr_line_2'],
      city: tavern['addr_city'],
      state_name: tavern['addr_state'],
      state_code:,
      zip: tavern['addr_zip'],
      country_name: tavern['addr_country'],
      country_code:,
      email: tavern['addr_email'],
    }
  }
end

module ISO3166
  module CountrySubdivisionMethods
    def find_subdivision_by_any_name(subdivision_str)
      subdivisions.select do |k, v|
        subdivision_str == k || v.name == subdivision_str || v.translations.values.include?(subdivision_str) || v.unofficial_names.include?(subdivision_str)
      end.values.first
    end
  end
end

def country_and_state(country, state)
  _country = ISO3166::Country.find_country_by_any_name(country) || ISO3166::Country.find_country_by_alpha2(country) || ISO3166::Country.find_country_by_alpha3(country)
  raise WhatCountryError, "couldn't parse #{country} as a country!" unless _country
  _state = _country.find_subdivision_by_any_name(state)
  raise WhatCountryError, "couldn't parse #{state} as a country!" unless _state
  { country_code: _country.alpha2, state_code: _state.code }
end

@client = Printful::Client.new(access_token: ENV['PRINTFUL_API_TOKEN'], store_id: ENV['PRINTFUL_STORE_ID'])

# @client.orders.create **generate_order(MockTavern.new, expedited: true)
binding.irb