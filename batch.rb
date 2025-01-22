require_relative './shirt'
require 'faraday/multipart'

SKIP_PPL_ALREADY_SHIRTED = false # could be true if you're so inclined!
def bucky(file)
  $buckyconn ||= Faraday.new('https://bucky.hackclub.com') do |f|
    f.request :multipart
    f.request :url_encoded
    f.adapter :net_http
  end

  payload = { file: Faraday::UploadIO.new(file, 'image/png') }
  $buckyconn.post { | req | req.body = payload }.body
end

def single_shirt(person)
  shirt_filez = shiperize(person)
  puts person['slack_id']
  if shirt_filez.empty?
    puts "\tno shirt?"
    return
  end

  person['shirt_design'] = shirt_filez.map { |shirt| { url: bucky(shirt) } }
  person['action_generate_shirt_design'] = nil
  person.save
end
def run_batch
  people_to_shirtify = Person.records filter: "AND({action_generate_shirt_design}#{', NOT({shirt_design})' if SKIP_PPL_ALREADY_SHIRTED})"

  n = people_to_shirtify.length
  puts "found #{n} #{'person'.pluralize(n)} who should have a cool shirt"

  people_to_shirtify.each &method(:single_shirt)
end

if __FILE__ == $PROGRAM_NAME
  run_batch
end