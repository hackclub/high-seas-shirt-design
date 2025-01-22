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

def render_shirt_and_add_to_at(person)
  shirts = generate_shirts(person)
  if shirts.any?
    person['shirt_design'] = shirts.map.with_index do |shirt, i|
      { url: bucky(shirt, "#{person.id}_#{i}.png") }
    end
  end
  person['action_generate_shirt_design'] = nil
  person.save
end

class Shirts < Grape::API
  helpers do
    def authorized?
      (headers['Authorization'] || params[:authorization])&.== ENV['AT_KEY']
    end

    def authorize!
      unless authorized?
        error!({ error: "who exactly are you?" }, 401)
      end
    end

    def person
      begin
        @person ||= Person.find(params[:user_id])
      rescue Norairrecord::Error
        error!('person not found :-(', 404)
      end
    end

  end
  before do
    authorize!
  end
  route_param :user_id do
    get do
      render_shirt_and_add_to_at person
      "done!"
    end
  end
end