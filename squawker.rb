require 'rubygems'
require 'sinatra'
require 'yaml'
require 'twitter'

use Rack::Auth::Basic do |username, password|
  username == 'admin' && password == '123123123'
end

routes = {
  :index => {:path => '/'},
  :add => {:path => '/add'},
  :license => {:path => '/license'},
  :settings => {:path => '/settings', :data => ['settings']},
  :squawks => {:path => '/squawks', :data => ['queued', 'fill', 'completed']},
}
# GET all the requests!
routes.each { |k, v|
  get v[:path] do
    v[:data].each{ |key| instance_variable_set("@#{key}", Dfile.load(key))} if v[:data]
    erb k
  end
}

post '/save' do
  Dfile.append(params[:type], {Time.now.utc.tv_sec => params[:message]})
  erb :add
end

post '/update_settings' do
  Dfile.overwrite('settings', params)
  redirect '/settings'
end

get '/check' do
  Squawk.new()
end

class Squawk

  def initialize
    @settings = Dfile.load('settings')
    @time_store = Dfile.load('time_store')
	  @last_squawked = DateTime.parse(Dfile.load('time_store')['last_squawked'].to_s).to_time.utc
    @last_filled = DateTime.parse(Dfile.load('time_store')['last_filled'].to_s).to_time.utc
    @queued = Dfile.load('queued')

    set_squawk_intervals

    @twitter = Twitter.configure do |config|
	  	config.consumer_key = @settings['consumer_key']
	  	config.consumer_secret = @settings['consumer_secret']
	  	config.oauth_token = @settings['oauth_token']
	  	config.oauth_token_secret = @settings['oauth_token_secret']
		end

    send_squawks
  end

  def send_squawks
    #Checks settings to see if sending fill should be attempted
    #kicks off queue/fill send checks
    case @settings['fill_mode']
      when 'always'
        send_fill
      when 'empty'
        send_fill if Dfile.load('queued').nil?
    end
    send_queued unless @queued.empty?
  end

  def send_queued
    if @last_squawked && @last_squawked + @count <=  Time.now.utc
      sq = @queued.first
      @twitter.update(sq[1])>
      Dfile.append('completed', {sq[0] => sq[1]})
      Dfile.remove_record('queued', sq[0])
      times = {'last_squawked' => Time.now.utc, 'last_filled' => @last_filled}
      Dfile.overwrite('time_store', times)
    end
  end

  def send_fill
    #NEED TO IMPLEMENT SENDING OF FILL!
    #@last_filled
    #@fill_count #send ever @fill_count seconds
  end

  def set_squawk_intervals
    {'unit' => 'count', 'fill_unit' => 'fill_count'}.each_pair do |unit, count|
      case @settings[unit]
        when 'hours'
          instance_variable_set("@#{count}", @settings[count].to_i * 60 * 60)
        when 'minutes'
          instance_variable_set("@#{count}", @settings[count].to_i * 60)
        when 'seconds'
          instance_variable_set("@#{count}", @settings[count].to_i)
      end
    end
  end

end

class Squawk
  require 'twitter'

  def self.tweet
  Twitter.configure do |config|

  end

  Twitter.update("cold!")
  end


end

class Dfile
  def self.load(file)
   d = YAML.load_file("#{File.dirname(__FILE__)}/data/#{file}.yml")
   return d unless d==false
  end

  def self.append(file, data)
    old = load(file)
    d = old.nil? ? data : old.merge!(data)
    File.open("#{File.dirname(__FILE__)}/data/#{file}.yml", 'w') do |f|
       f.write(d.to_yaml)
     end
  end

  def self.overwrite(file, data)
    File.open("#{File.dirname(__FILE__)}/data/#{file}.yml", 'w') do |f|
       f.write(data.to_yaml)
     end
  end

  def self.remove_record(file, key)
    d = load(file)
    d.delete(key)
    overwrite(file, d)
  end

end

