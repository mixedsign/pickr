require 'rubygems'
require 'rack'
require 'bundler'
Bundler.require

require 'init'

run Sinatra::Application
