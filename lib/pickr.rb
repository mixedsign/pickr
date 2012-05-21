#
# = Pickr - A Gallery tool for Photographers
# These classes represent are an abstration away from the Flickr API.
# They provide methods for creating a gallery of photos for selecting
# and submitting to the photographer.
#

require 'rubygems'
require 'flickraw'
require 'yaml'
require 'json'
require 'uri'

module Pickr
  $config = YAML.load_file(File.join(File.expand_path(File.dirname(__FILE__)), '../config.yml'))

  FLICKR_PHOTO_URL    = "http://www.flickr.com/photos".freeze
  FLICKR_STATIC_URL   = "http://farm5.static.flickr.com".freeze

  # TODO: make these optionally configurable in a db also
  API_KEY             = $config['flickr_api_key'].freeze
  SHARED_SECRET       = $config['flickr_shared_secret'].freeze
  AUTH_TOKEN          = $config['auth_token'].freeze
  USER_ID             = $config['user_id'].freeze
  PRIMARY_PHOTO_CACHE = $config['primary_photo_cache'].freeze
  GALLERY_TITLE       = $config['gallery_title'].freeze
  SET_PHOTO_SIZE      = $config['set_photo_size'].freeze

  FlickRaw.api_key       = API_KEY    
  FlickRaw.shared_secret = SHARED_SECRET

  class Error < Exception; end

  class Cached
    @@cache = {}
    def self.cache
      @@cache
    end

    def self.clear_cache
      @@cache = {}
    end

    def self.cache_by(value, &blk)
      if cache.has_key?(value) then cache[value]
      else blk.call(value)
      end
    end
  end

  class Person < Cached
    attr_accessor :nsid, :username, :realname, :location

    alias id nsid

    def initialize(nsid, username, realname, location)
      @nsid, @username, @realname, @location =
        nsid, username, realname, location
    end

    def username(opt=nil)
      if opt == :urlencoded
        ::URL::Escape.encode(@username)
      else
        @username
      end
    end

    def self.get(username)
      cache_by username do
        id =
          if username =~ /\d{8,8}\@N\d\d/
            username
          else
            p =
              begin
                flickr.people.findByUsername :username => username
              rescue => e
                raise Error, "Couldn't find user, '#{username}'"
              end

            p.id 
          end

        info =
          begin
            flickr.people.getInfo :user_id => id
          rescue
            raise Error, "Couldn't retrieve user information for, '#{username}'"
          end

        username = info.username if id == username

        cache[username] = new(id, username, info.realname, info.location)
      end
    end

    def gallery
      @gallery ||= Gallery.get(@nsid)
    end
  end

  class PhotoSet < Cached
    attr_reader   :id, :description, :photos, :primary_photo_id  
    attr_accessor :title

    def initialize(set, photos=[])
      @set              = set
      @id               = set.id
      @title            = set.title
      @description      = set.description
      @photos           = construct_photos(photos)
      @primary_photo_id = set.primary
    end
  
    private
    
    def construct_photos(photos)
      photos.map {|p| Photo.new(p.id, p.title, p.server, p.secret) }
    end

    public
  
    def primary_photo
      @primary_photo ||= Photo.new(@set.primary, @set.title, @set.server, @set.secret)
    end
  
    def self.get(id)
      cache_by id do
        set  = flickr.photosets.getPhotos :photoset_id => id
        info = flickr.photosets.getInfo   :photoset_id => id
        cache[id] = new(info, set.photo)
      end
    end
    
    def url
      "#{FLICKR_PHOTO_URL}/#{USER_ID}/sets/#{@id}"
    end
  
    def to_hash
      { id => primary_photo.to_square_url }
    end
  end
  
  class Photo < Cached
    attr_reader   :title
    attr_accessor :id, :secret, :server
  
    def initialize(id, title, server, secret)
      @id     = id
      @title  = title != '' ? title : "Untitled"
      @server = server
      @secret = secret
    end

    def self.get(id)
      cache_by id do
        photo = flickr.photos.getInfo :photo_id => id
        cache[id] = new(id, photo.title, photo.server, photo.secret)
      end
    end
  
    # 
    # Generates url for photo of type:
    # - square
    # - thumbnail
    # - original
    # - medium
    # - page
    # - lightbox
    # 
    def url(type=SET_PHOTO_SIZE)
      return @url unless @url.nil? # allows us to override url generation

      base_url = "#{FLICKR_STATIC_URL}/#{@server}/#{@id}_#{@secret}"
      page_url = "#{FLICKR_PHOTO_URL}/#{USER_ID}/#{@id}"

      sizes = {
        :square    => "#{base_url}_s.jpg",
        :thumbnail => "#{base_url}_t.jpg",
        :original  => "#{base_url}.jpg",
        :medium    => "#{base_url}_m.jpg",
        :page      => page_url,
        :lightbox  => "#{page_url}/lightbox"
      }
      
      unless sizes.keys.include?(type.to_sym)
        raise Error, "'#{type}' is not a valid URL type" 
      end

      sizes[type.to_sym]
    end

    def url=(value)
      @url = value
    end

  end # Photo
  

  class Gallery < Cached
    attr_reader :user_id, :sets

    def initialize(user_id, sets)
      @user_id = user_id
      @sets    = sets.map { |s| PhotoSet.new(s) }
    end
  
    def self.get(user_id)
      cache_by user_id do
        sets = flickr.photosets.getList :user_id => user_id
        cache[user_id] = new(user_id, sets)
      end
    end
  
    def to_hash(&block)
      h = {}
      sets.each do |s|
        block.call(s)
        h[s.id] = s.primary_photo.to_square_url
      end
      h
    end

    def to_json(&block)
      to_hash(&block).to_json
    end

  end # Gallery
  
end # Pickr
