require 'norairrecord'
require 'dotenv'
require 'rqrcode'
require 'prawn'
require 'pry'
require 'faraday'
require 'active_support'
require 'active_support/number_helper'
require 'active_support/core_ext'

include ActiveSupport::NumberHelper

Dotenv.load

def get_slack_user_info(slack_id)
  conn = Faraday.new(url: 'https://slack.com/api')

  response = conn.post("users.info",
                       {
                         user: slack_id,
                         token: ENV["SLACK_TOKEN"]
                       })
  JSON.parse(response.body)
end

def get_username(slack_id)
  user_info = get_slack_user_info(slack_id)
  user_info.dig('user', 'profile', 'display_name')
end

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

QR_SIZE = 120
SPACING = 20
ITEMS_PER_ROW = 4
ROWS_PER_PAGE = 4
ITEMS_PER_PAGE = ITEMS_PER_ROW * ROWS_PER_PAGE

PAGE_HEIGHT = 800
PAGE_WIDTH = 612
HEADER_HEIGHT = 120
LEFT_MARGIN = 5

def shiperize(person)

  ships = person.ships.each_with_object({}) do |ship, acc|
    title = ship['title'].gsub('–', '-').split('-').first
    if acc[title]
      acc[title]['doubloons'] += ship['doubloon_payout_adjusted'] || 0
      acc[title]['hours'] += ship['total_hours'] || 0
    else
      acc[title] = {
        'doubloons' => ship['doubloon_payout_adjusted'] || 0.0,
        'hours' => ship['total_hours'].to_i || 0.0,
        'deploy_url' => ship['deploy_url'],
        'title' => title
      }
    end
  end.values

  ships.reject! { |ship| ship['hours'] == 0 || ship['deploy_url'].blank? }
  puts "Shiperizing #{person.nice_full_name}"

  handle = get_username(person['slack_id'])

  ships.each_slice(ITEMS_PER_PAGE).with_index do |page_ships, page_index|
    pdf = Prawn::Document.new(page_size: [PAGE_WIDTH, PAGE_HEIGHT])

    pdf.font_families.update(
      "bank_printer" => {
        normal: 'F25_Bank_Printer.ttf',
        bold: 'F25_Bank_Printer_Bold.ttf',
      }
    )

    pdf.font "bank_printer"

    pdf.canvas do
      pdf.fill_color "000000"
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.right, pdf.bounds.top
    end
    pdf.fill_color 'FFFFFF'

    page_ships.each_with_index do |ship, index|

      row = index / ITEMS_PER_ROW
      col = index % ITEMS_PER_ROW

      x_position = LEFT_MARGIN + (col * (QR_SIZE + SPACING))
      y_position = PAGE_HEIGHT - (HEADER_HEIGHT + (row * (QR_SIZE + SPACING + 40)))

      qr = RQRCode::QRCode.new(ship['deploy_url'])
      png = qr.as_png(
        bit_depth: 1,
        border_modules: 2,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: 'white',
        file: nil,
        fill: 'black',
        module_px_size: 4,
        resize_exactly_to: false,
        resize_gte_to: false,
      )

      qr_path = "#{Digest::MD5.hexdigest(ship['title'].downcase)}_qr.png"
      png.save(qr_path)

      pdf.image qr_path, at: [x_position, y_position], width: QR_SIZE

      pdf.text_box ship['title'],
                   at: [x_position, y_position - QR_SIZE - 5],
                   width: QR_SIZE,
                   height: 20,
                   align: :center,
                   size: 10,
                   overflow: :shrink_to_fit

      x_center = x_position + (QR_SIZE / 2)
      stats_y = y_position - QR_SIZE - 25

      content = ""
      content_width = 0
      icon_size = 10

      if ship['hours']
        display_hours = number_to_rounded(ship['hours'], precision: 1, strip_insignificant_zeros: true)
        hours_text = "#{display_hours}h"
        content_width += pdf.width_of(hours_text, size: 10)
      end

      if ship['doubloons']
        doubloon_value = ship['doubloons'].to_f.round(0).to_s
        content_width += pdf.width_of(doubloon_value, size: 10) + icon_size + 4
        content_width += 5 if ship['hours']
      end

      start_x = x_center - (content_width / 2)
      current_x = start_x

      if ship['hours']
        pdf.text_box hours_text,
                     at: [current_x, stats_y],
                     size: 10
        current_x += pdf.width_of(hours_text, size: 10) + 5
      end

      if ship['doubloons']
        pdf.text_box doubloon_value,
                     at: [current_x, stats_y],
                     size: 10

        pdf.image "./doubloon.png",
                  at: [current_x + pdf.width_of(doubloon_value, size: 10) + 2, stats_y + 2],
                  width: icon_size
      end

      File.delete(qr_path)
    end

    pdf_filename = "./output/#{person.nice_full_name.downcase.gsub(' ', '_')}_shirt_#{page_index + 1}.pdf"
    png_filename = pdf_filename.sub('.pdf', '.png')
    pdf.render_file(pdf_filename)
    system("magick -density 300 #{pdf_filename} -quality 100 #{png_filename}")
    File.delete(pdf_filename)
    puts "Generated shirt PNG page #{page_index + 1}: #{png_filename}"
  end
end

person = Person.records(max_records: 1, filter: "slack_id = '#{ARGV[0]}'").first

shiperize(person)
