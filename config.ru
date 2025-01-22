require_relative './batch'

class API
  HEADERS = {'content-type' => 'text/plain'}
  def call(env)
    return [403, HEADERS, ['wat?']]  unless env['HTTP_AUTHORIZATION']&.== ENV['AT_KEY']
    begin
      /\/(?<record_id>rec.*)/ =~ env['PATH_INFO']
      return [404, HEADERS, ['where?']] unless record_id
      person = Person.find record_id
    rescue Norairrecord::Error
      return [404, HEADERS, ['who...?']]
    end
    single_shirt person
    return [200, HEADERS, ['done!']]
  end
end

run API.new
