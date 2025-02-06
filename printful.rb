require 'printfulrb'
require 'countries'
require_relative './models'
require 'active_support/inflector'

I18n.backend.store_translations(:en, i18n: {
  transliterate: {
    rule: {
      'ș' => 's',
      'Т' => 'T',
      'о' => 'o',
      'Ț' => 'T',
      '–' => '-',
      'ț' => 't',
      'Ș' => 'S'
    }
  }
})

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
    message: '🏴‍☠️',
    logo_url: 'https://cloud-qbqw0pyux-hack-club-bot.vercel.app/0image.png',
    store_name: "Hack Club"
  }
end

def generate_shirt_items(person)
  variant_id = size_to_variant(person['shirt_size'])
  shirt_designs = person['shirt_design']&.map { |img| img['url'] }
  shirt_designs&.map&.with_index do |url, index|
    {
      variant_id:,
      quantity: 1,
      retail_price: 5,
      name: "#{person['first_name'].first}'s shirt! #{"(#{index + 1} of #{shirt_designs.length})" unless shirt_designs.length == 1}",
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
            width: 1717,
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
    # @people = Person.where "slack_id='U0807ADEC6L'"
    @people = [
      {
          'first_name' => ['Manan'],
          'shirt_size'=>'Medium',
          'shirt_design' => [{'url'=> 'https://v5.airtableusercontent.com/v3/u/37/37/1738008000000/hJE8Vef9g-m4Z-xfmcMytw/QRBP4WeiTjqk3mu3A-J2ab4ZP4AAdQXlalVa8QmCB4PXsfdcGonhLFRnsaTSQUCuWWZdXU5qgpuFp5jse486_CGQeKaLw48rDkV2cbL2_xeQ9FgPWPIYScFdW2LdgPNQvBg6K9uSuLJT3jI_u9JRgQ/KrV-OU8G-o7UYpsencgM0Z-CX_x-1swQEzszqwjd9KA'}]
      }
    ]
  end

  attr_accessor :people

  def id
    @id ||= "recFAKE#{rand(10000)}#{rand(10000)}"
    puts @id
    @id
  end

  def [](key)
    FIELDS[key.to_sym]
  end
end

class WhatCountryError < StandardError; end

def generate_order(tavern, expedited: false)
  raise "no address?" unless tavern['shirt_delivery_address']
  country_and_state(tavern['addr_country'].first&.strip, tavern['addr_state'].first&.strip) => { country_code:, state_code: }
  raise "this is literally one guy" if tavern.people.one?
  items = tavern.people.flat_map { |person| generate_shirt_items(person) }.compact
  raise "nobody here shipped something" unless items.any?
  gift = generate_gift_info(tavern)
  packing_slip = generate_packing_slip_info(tavern)
  puts "all the shit been generated ^w^"
  {
    external_id: tavern.id.gsub('rec', 'Tavern.'),
    shipping: expedited ? 'PRINTFUL_FAST' : 'STANDARD',
    items:,
    retail_costs: {
      currency: 'USD',
      subtotal: items.length * 5
    },
    gift:,
    packing_slip:,
    recipient: {
      name: "#{tavern['addr_first_name']&.first} #{tavern['addr_last_name']&.first}",
      address1: tavern['addr_line_1']&.first,
      address2: tavern['addr_line_2']&.first,
      city: tavern['addr_city']&.first,
      state_name: tavern['addr_state']&.first,
      state_code:,
      zip: tavern['addr_zip']&.first,
      country_name: tavern['addr_country']&.first,
      country_code:,
      email: tavern['addr_email']&.first,
    }.compact,
    confirm: true
  }
end

# lol countries can't find subdivisions by unofficial names
module ISO3166
  module CountrySubdivisionMethods
    def find_subdivision_by_any_name(subdivision_str)
      subdivisions.select do |k, v|
        subdivision_str == k || v.name == subdivision_str || v.translations&.values.include?(subdivision_str) || v.unofficial_names&.include?(subdivision_str) || stupid_compare(v.translations&.values, subdivision_str) || v.unofficial_names && stupid_compare(v.unofficial_names, subdivision_str)
      end.values.first
    end
    def stupid_compare(arr, val)
      arr.map { |s| tldc(s)}.include?(val)
    end
    def tldc(s)
      ActiveSupport::Inflector.transliterate(s.strip).downcase
    end
  end
end

# lol printfulrb can't pass url params
module Printful
  class OrdersResource
    def create(**params)
      response = post_request("orders#{'?confirm=true' if params.delete(:confirm)}", body: params)
      Order.new(response.body["result"])
    end  end
end

def country_and_state(country, state)
  _country = ISO3166::Country.find_country_by_any_name(country) || ISO3166::Country.find_country_by_alpha2(country) || ISO3166::Country.find_country_by_alpha3(country)
  raise WhatCountryError, "couldn't parse #{country} as a country!" unless _country
  _state = _country.find_subdivision_by_any_name(state)&.code || ('XX' if state == 'xx')
  raise WhatCountryError, "couldn't parse #{state} as a state!" unless _state
  { country_code: _country.alpha2, state_code: _state }
end

@client = Printful::Client.new(access_token: ENV['PRINTFUL_API_TOKEN'], store_id: ENV['PRINTFUL_STORE_ID'])

def tav(id, exp: false)
  tav = Tavern.find id
  ord = @client.orders.create **generate_order(tav, expedited: exp)
  pp ord
  tav['shirts_ordered_at'] = Time.now
  tav.save
  ord
end
#
binding.irb