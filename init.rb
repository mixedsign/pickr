require 'rubygems'
require 'sinatra'
require 'haml'
require 'sinatra/static_assets'
require 'sinatra/url_for'

require 'lib/pickr'

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

get '/?' do
  haml :entry
end

get '/sets' do
  @person = Pickr::Person.get(params[:u])
  
  haml :gallery
end

get '/:user_id/sets' do
  @person  = Pickr::Person.get(params[:user_id])

  haml :gallery
end

get '/:user_id/sets/:set_id' do
  @person = Pickr::Person.get(params[:user_id])
  @set    = Pickr::PhotoSet.get(params[:set_id])

  haml :set
end
