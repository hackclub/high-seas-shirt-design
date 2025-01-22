require 'rqrcode'
require 'tilt'
require 'json'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string'
require 'active_support/number_helper'
require 'norairrecord'
require 'base64'
require 'grover'

include ActiveSupport::NumberHelper

Grover.configure do |config|
  # n.b.: this is bad!
  # make sure you sanitize stuff coming from airtable :-P
  config.allow_file_uris = true
end

def setup_files
  `mkdir -p /tmp/high-seas-shirts/`
  `cp -R #{__dir__}/assets/* /tmp/high-seas-shirts`
end

$erb_cache = {}

def erb(filename, locals: {})
  $erb_cache[filename] ||= Tilt.new(filename)
  $erb_cache[filename].render(binding, locals)
end

ITEMS_PER_ROW = 3
ROWS_PER_SHIRT = 5
ITEMS_PER_SHIRT = ITEMS_PER_ROW * ROWS_PER_SHIRT

Norairrecord.api_key = ENV["AIRTABLE_PAT"]

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

class Shirt
  attr_reader :ships, :handle

  def initialize(ships, handle)
    @ships = ships
    @handle = handle
  end
end

def generate_qr_data_uri(url)
  qr = RQRCode::QRCode.new(url)
  png = qr.as_png(
    bit_depth: 1,
    color_mode: ChunkyPNG::COLOR_GRAYSCALE,
    color: 'black',
    fill: '00000000',
    module_px_size: 8
  )
  "data:image/png;base64,#{Base64.strict_encode64(png.to_blob)}"
end

def v1_rotaté
  "transform: rotate(#{rand(2..5) * (rand(2) == 0 ? -1 : 1)}deg);"
end

def get_slack_user_info(slack_id)
  conn = Faraday.new(url: 'https://slack.com/api')
  response = conn.post('users.info', {
    user: slack_id,
    token: ENV["SLACK_TOKEN"]
  })
  JSON.parse(response.body)
end

def get_name(slack_id)
  user_info = get_slack_user_info(slack_id)
  display_name = user_info.dig('user', 'profile', 'display_name')
  return "@#{display_name}" if display_name
  user_info.dig('user', 'profile', 'first_name')
end

def process_ships(person)
  ships = person.ships.each_with_object({}) do |ship, acc|
    title = ship['title'].gsub('–', '-').gsub(':', '-').split('-').first
    if acc[title]
      acc[title][:doubloons] += ship['doubloon_payout_adjusted'] || 0
      acc[title][:hours] += ship['total_hours'] || 0
      acc[title][:in_ysws] ||= ship['has_ysws_submission_id']
    else
      acc[title] = {
        doubloons: ship['doubloon_payout_adjusted'] || 0.0,
        hours: ship['total_hours'].to_i || 0.0,
        deploy_url: ship['deploy_url'],
        title:,
        in_ysws: ship['has_ysws_submission_id']
      }
    end
  end.values

  ships.reject { |ship|
    ship[:hours] == 0 ||
      ship[:deploy_url].blank? ||
      ship[:doubloons] == 0
  }
end

def generate_shirts(person)
  ships = process_ships(person)

  return unless ships.present?
  handle = get_name(person['slack_id'])
  total_pages = (ships.length.to_f / ITEMS_PER_SHIRT).ceil
  pngs = []

  ships.each_slice(ITEMS_PER_SHIRT).with_index(1) do |page_ships, page_number|
    shirt = Shirt.new(page_ships, handle)

    html_filename = "/tmp/high-seas-shirts/#{person.id}_shirt_#{page_number}.html"
    File.write(html_filename, erb('shirt_template.erb', locals: { shirt:, ships: }))
    puts "wrote #{html_filename}..."

    pngs << Grover.new("file://#{html_filename}",
                       full_page: true,
                       viewport: {
                         width: 2700,
                         height: 3000,
                       },
                       omit_background: true
    ).to_png
    File.delete(html_filename)

    puts "Generated shirt design #{page_number}/#{total_pages}"
  end
  pngs
end

if __FILE__ == $PROGRAM_NAME
  setup_files
  person = Person.records(max_records: 1, filter: "slack_id = '#{ARGV[0]}'").first
  shirts = generate_shirts(person)

  shirts.each_with_index do |shirt, i|
    File.open("#{i}.png", 'wb') { |f| f << shirt }
  end
end