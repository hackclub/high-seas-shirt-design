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

def shirt_a_person(person)
  shirts = generate_shirts(person)
  person['shirt_design'] = nil
  unless shirts.blank?
    person['shirt_design'] = shirts.map.with_index do |shirt, i|
      { url: bucky(shirt, "#{person.id}_#{i}.png") }
    end
  end
  person['action_generate_shirt_design'] = nil
end

people = Person.where('action_generate_shirt_design')
puts "#{people.length}"
people.each { |person| shirt_a_person(person) }

Person.batch_save(people)
