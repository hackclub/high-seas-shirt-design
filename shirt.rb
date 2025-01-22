require 'norairrecord'
require 'dotenv'
require 'rqrcode'
require 'prawn'
require 'pry'
require 'faraday'
require 'active_support'
require 'active_support/number_helper'
require 'active_support/core_ext'
require 'stringio'

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
  display_name = user_info.dig('user', 'profile', 'display_name')
  return "@#{display_name}" if display_name
  user_info.dig('user', 'profile', 'first_name')
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

QR_SIZE = 110
SPACING = 5
ITEMS_PER_ROW = 3
ROWS_PER_PAGE = 5
ITEMS_PER_PAGE = ITEMS_PER_ROW * ROWS_PER_PAGE

PAGE_HEIGHT = 820
PAGE_WIDTH = 612

ARTS = {
  0 => {
    file: './art_2.png',
    next_row_offset: 30,
    rows_til_offset: 0,
    opts: {
      at: [PAGE_WIDTH * 0.5 + 10 + 10, PAGE_HEIGHT - 40],
      width: PAGE_WIDTH * 0.33
    }
  },
  1 => {
    file: './art_3.png',
    opts: {
      at: [-20, PAGE_HEIGHT - QR_SIZE - 170],
      width: QR_SIZE * 2.2
    }
  },
  3 => {
    file: './art_1.png',
    opts: {
                  at: [PAGE_WIDTH * 0.6 - 30, PAGE_HEIGHT - (QR_SIZE * 3) - 185 - 20 - 15 - 10],
                  width: QR_SIZE * 2.1
    }
  }
}

def shiperize(person)
  png_filez = []
  ships = person.ships.each_with_object({}) do |ship, acc|
    title = ship['title'].gsub('–', '-').gsub(':','-').split('-').first
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

  # # testing:
  # # for one ship:
  # ships = [ships.first]
  # # for more ships:
  # ships.concat(ships)

  ships.reject! { |ship|
    ship['hours'] == 0 ||
    ship['deploy_url'].blank? ||
    ship['doubloons'] == 0
  }
  puts "Shiperizing #{person.nice_full_name}"

  handle = get_username(person['slack_id'])

  def generate_qr_row(ships, x, y, align=:left, pdf)
    ships.each_with_index do |ship, index|
      shifted_x = QR_SIZE * (index + (align == :left ? 0 : 2))
      generate_qr(ship, shifted_x, y, pdf)
    end
  end

  def generate_qr(ship, x, y, pdf, size=QR_SIZE, font_size=10)
      qr = RQRCode::QRCode.new(ship['deploy_url'])
      png = qr.as_png(
        bit_depth: 1,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: 'black',
        fill: '00000000',
        file: nil,
        module_px_size: 4,
        resize_exactly_to: false,
        resize_gte_to: false,
      )

      pdf.image StringIO.new(png.to_blob), at: [x, y], width: size

      pdf.text_box ship['title'],
                   at: [x, y - size + 2],
                   width: size,
                   height: font_size,
                   align: :center,
                   size: font_size,
                   overflow: :shrink_to_fit

      x_center = x + (size / 2)
      stats_y = y - size - (font_size+5)

      content = ""
      content_width = 0
      icon_size = font_size

      if ship['hours']
        display_hours = number_to_rounded(ship['hours'], precision: 1, strip_insignificant_zeros: true)
        hours_text = "#{display_hours}h /"
        content_width += pdf.width_of(hours_text, size: font_size)
      end

      if ship['doubloons']
        doubloon_value = ship['doubloons'].to_f.round(0).to_s
        content_width += pdf.width_of(doubloon_value, size: font_size) + icon_size + 4
        content_width += 5 if ship['hours']
      end

      start_x = x_center - (content_width / 2)
      current_x = start_x

      if ship['hours']
        pdf.text_box hours_text,
                     at: [current_x, stats_y],
                     size: font_size
        current_x += pdf.width_of(hours_text, size: font_size) + 5
      end

      if ship['doubloons']
        pdf.text_box doubloon_value,
                     at: [current_x, stats_y],
                     size: font_size

        pdf.image "./doubloon.png",
                  at: [current_x + pdf.width_of(doubloon_value, size: font_size) + 2, stats_y + 2],
                  width: icon_size
      end
  end

  ships.each_slice(ITEMS_PER_PAGE).with_index do |page_ships, page_index|
    pending_offset = rto = nil
    row_shifts = [:left, :left, :right, :right].cycle
    row_shifts.next

    offset = 0
    puts "page #{page_index + 1}"
    pdf = Prawn::Document.new(page_size: [PAGE_WIDTH, PAGE_HEIGHT])

    pdf.font_families.update(
      "bank_printer" => {
        normal: 'F25_Bank_Printer.ttf',
        bold: 'F25_Bank_Printer_Bold.ttf',
      }
    )

    pdf.font "bank_printer"

    #  while testing, fill with blue background
    pdf.canvas do
      pdf.fill_color "D2E6FF"
      pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top], pdf.bounds.right, pdf.bounds.top
    end
    pdf.fill_color '000000'


    pdf.text_box "#{handle} - #{'project'.pluralize(ships.length)}",
                 at: [PAGE_WIDTH * 0.05, PAGE_HEIGHT - 90],
                 height: 30,
                 width: ((QR_SIZE + SPACING) * 3) - (PAGE_WIDTH * 0.15),
                 # ^ number 100% pulled out of ass ^
                 align: :left,
                 size: 30,
                 min_font_size: 3,
                 overflow: :shrink_to_fit


    case page_ships.length
    when 1
      pdf.image ARTS[0][:file], **ARTS[0][:opts]
      generate_qr(page_ships.first, 55, PAGE_HEIGHT-113, pdf, QR_SIZE*1.8, 21)
    when 2
      pdf.image ARTS[0][:file], **ARTS[0][:opts]
      generate_qr(page_ships[0], 5,        PAGE_HEIGHT-113, pdf, QR_SIZE*1.3, 13)
      generate_qr(page_ships[1], 5+143+15, PAGE_HEIGHT-113, pdf, QR_SIZE*1.3, 13)
    else
      page_ships.each_slice(ITEMS_PER_ROW).with_index do |row_ships, row_index|
        row_shift = row_shifts.next
          generate_qr_row row_ships,
                          row_shift == :right ? QR_SIZE * 2.1 : 0,
                          PAGE_HEIGHT - QR_SIZE - (row_index * (QR_SIZE + SPACING + 20)) + offset,
                          row_shift,
                          pdf
        if (art = ARTS[row_index])
          pdf.image art[:file], **art[:opts]
          pending_offset = art[:next_row_offset]
          rto = art[:rows_til_offset]
        end
        if pending_offset
          if rto == 0
            offset -= pending_offset
            pending_offset = rto = nil
          else
            rto -= 1
          end
        end
      end
      end

    pdf_filename = "/tmp/#{person.id}_shirt_#{page_index + 1}.pdf"
    png_filename = pdf_filename.sub('.pdf', '.png')
    pdf.render_file(pdf_filename)
    system("magick -density 600 #{pdf_filename} -quality 100 #{png_filename}")
    File.delete(pdf_filename)
    puts "Generated shirt PNG page #{page_index + 1}: #{png_filename}"
    png_filez << png_filename
  end
  png_filez
end

if __FILE__ == $PROGRAM_NAME
  person = Person.records(max_records: 1, filter: "slack_id = '#{ARGV[0]}'").first

  shiperize(person)
end