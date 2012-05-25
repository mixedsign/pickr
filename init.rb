require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'sinatra/static_assets'
require 'sinatra/url_for'
require 'rack-flash'

require 'lib/pickr'

enable :sessions
use Rack::Flash

get '/thumbnail/:id' do
  @photo = Pickr::Photo.get(params[:id])

  haml :thumbnail, :layout => false
end

post '/complete-selection' do
end

post '/send-request' do
  # record request
  # send email
  ""
end

get '/style/default.css' do
  sass :style
end

get '/?' do
  haml :entry
end

get '/sets' do
  begin
    @person = Pickr::Person.get(params[:u])
  rescue Pickr::Error => e
    flash[:error] = e.message
    redirect to('/')
  end
  
  haml :gallery
end

get '/:user_id/sets' do
  begin
    @person = Pickr::Person.get(params[:user_id])
  rescue Pickr::Error => e
    flash[:error] = e.message
    redirect to('/')
  end

  haml :gallery
end

get '/:user_id/sets/:set_id' do
  begin
    @person = Pickr::Person.get(params[:user_id])
    @set    = Pickr::PhotoSet.get(params[:set_id])
  rescue
    flash[:error] = e.message
    redirect to("/#{params[:user_id]}/sets")
  end

  haml :set
end
