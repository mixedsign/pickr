require 'rubygems'
require 'sinatra'
require 'haml'
require 'sinatra/static_assets'

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

get '/:user_id/sets' do
	@user_id = params[:user_id]
	@title   = @user_id
	@gallery = Pickr::Gallery.get(params[:user_id])

	haml :gallery
end

get '/:user_id/sets/:set_id' do
	@set = Pickr::PhotoSet.get(params[:set_id])
	@user_id = params[:user_id]

	haml :set
end

