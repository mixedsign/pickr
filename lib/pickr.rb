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
        ::URI.escape(@username)
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

        if info.respond_to?(:realname) && info.respond_to?(:location)
          cache[username] = new(id, username, info.realname, info.location)
        else
          cache[username] = new(id, username, '', '')
        end
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
      @user_id          = set.respond_to?(:owner) && set.owner
      @title            = set.title
      @description      = set.description
      @photos           = construct_photos(photos)
      @primary_photo_id = set.primary
    end
  
    private
    
    def construct_photos(photos)
      photos.map { |p| Photo.new(:id => p.id, :nsid => @user_id, :title => p.title, :server => p.server, :secret => p.secret) }
    end

    public
  
    def primary_photo
      @primary_photo ||= Photo.new(:id => @set.primary, :title => @set.title, :server => @set.server, :secret => @set.secret, :nsid => @user_id)
    end
  
    def self.get(id)
      cache_by id do
        begin
          set  = flickr.photosets.getPhotos :photoset_id => id
          info = flickr.photosets.getInfo   :photoset_id => id
        rescue
          raise Error, "Couldn't retrieve photoset #{id}"
        end
        cache[id] = new(info, set.photo)
      end
    end
    
    def url
      "#{FLICKR_PHOTO_URL}/#{@user_id}/sets/#{@id}"
    end
  
    def to_hash
      { id => primary_photo.to_square_url }
    end
  end
  
  class Photo < Cached
    attr_reader   :title, :nsid
    attr_accessor :id, :secret, :server
  
    def initialize(args)
      @id      = args[:id]     || raise(Error, "id is required")
      @server  = args[:server] || raise(Error, "server is required")
      @secret  = args[:secret] || raise(Error, "secret is required")
      @user_id = args[:nsid]
      @title   = args[:title] != '' ? title : "Untitled"
    end

    def self.get(id)
      cache_by id do
        begin
          photo = flickr.photos.getInfo :photo_id => id
        rescue
          raise Error, "Couldn't retrieve photo #{id}"
        end

        user_id = photo.respond_to?(:owner) && photo.owner.respond_to?(:nsid) && photo.owner.nsid

        cache[id] = new(:id => id, :title => photo.title, :server => photo.server, :secret => photo.secret, :nsid => user_id)
      end
    end
  
    # 
    # Generates url for photo of type:
    # - square
    # - square75
    # - square150
    # - thumbnail
    # - original
    # - medium
    # - page
    # - lightbox
    # 
    def url(type=SET_PHOTO_SIZE)
      return @url unless @url.nil? # allows us to override url generation

      @user_id ||= Photo.get(@id).nsid

      base_url = "#{FLICKR_STATIC_URL}/#{@server}/#{@id}_#{@secret}"
      page_url = "#{FLICKR_PHOTO_URL}/#{@user_id}/#{@id}"

      sizes = {
        :square    => "#{base_url}_s.jpg",
        :square150 => "#{base_url}_q.jpg",
        :thumbnail => "#{base_url}_t.jpg",
        :original  => "#{base_url}.jpg",
        :medium    => "#{base_url}_m.jpg",
        :page      => page_url,
        :lightbox  => "#{page_url}/lightbox"
      }

      # alias for :square
      sizes[:square75] = sizes[:square]
      
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
        begin
          sets = flickr.photosets.getList :user_id => user_id
        rescue
          raise Error, "Couldn't retrieve photosets for user #{user_id}"
        end
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
