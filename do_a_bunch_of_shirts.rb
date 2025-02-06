require 'grape'
require 'stringio'
require_relative './render'
require 'faraday'
require 'faraday/multipart'

def bucky(data, filename)
  $buckyconn ||= Faraday.new('https://bucky.hackclub.com') do |f|
    f.request :multipart
    f.request :url_encoded
    f.adapter :net_http
  end

  payload = { file: Faraday::UploadIO.new(StringIO.new(data), 'image/png', filename) }
  $buckyconn.post { |req| req.body = payload }.body
end

@shirted_people = []

def shirt_a_person(person)
  shirts = generate_shirts(person)
  person['shirt_design'] = nil
  unless shirts.blank?
    person['shirt_design'] = shirts.map.with_index do |shirt, i|
      { url: bucky(shirt, "#{person.id}_#{i}.png") }
    end
  end
  person['action_generate_shirt_design'] = nil
  @shirted_people << person
end

ppl = Person.where('action_generate_shirt_design', max_records: 100)
puts "#{ppl.length}"
ppl.each_slice(10) do |people|
  @shirted_people = []
  begin
    people.each { |person| shirt_a_person(person) }
  rescue Interrupt, Norairrecord::Error
    Person.batch_save(@shirted_people)
  end
  puts "saving"
  Person.batch_save(@shirted_people)
end