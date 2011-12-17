require 'rubygems'
require 'sinatra'
require 'yaml'

use Rack::Auth::Basic do |username, password|
  username == 'admin' && password == '123123123'
end

get '/' do
  erb :index
end

get '/squawks' do
  @scheduled = Dfile.load("scheduled")
  @fill = Dfile.load("fill")
  @completed = Dfile.load("completed")
  erb :squawks
end

get '/add' do
  erb :add
end

post '/save' do
  Dfile.append(params[:type], {Time.now.utc.tv_sec => params[:message]})
  erb :add

end

get '/settings' do
  @settings = Dfile.load("settings")
  erb :settings
end

post '/update_settings' do
  Dfile.overwrite("settings", params)
  redirect '/settings'
end

get '/license' do
  erb :license
end

class Dfile
  def self.load(file)
   d = YAML.load_file("#{File.dirname(__FILE__)}/data/#{file}.yml")
   return d unless d==false
  end

  def self.append(file, data)
    old = load(file)
    data = data
    d = old.nil? ? data : old.merge!(data)
    File.open("#{File.dirname(__FILE__)}/data/#{file}.yml", 'w')do |f|
       f.write(d.to_yaml)
     end
  end

  def self.overwrite(file, data)
    File.open("#{File.dirname(__FILE__)}/data/#{file}.yml", 'w')do |f|
       f.write(data.to_yaml)
     end
  end

end

