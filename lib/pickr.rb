#
# Pickr - A Gallery tool for Photographers
# ========================================
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

  API_KEY             = $config['flickr_api_key'].freeze
  SHARED_SECRET       = $config['flickr_shared_secret'].freeze
  AUTH_TOKEN          = $config['auth_token'].freeze

  FlickRaw.api_key       = API_KEY    
  FlickRaw.shared_secret = SHARED_SECRET

  class Error < Exception; end

  module Cached
    @@cache = {}
    def cache
      @@cache
    end

    def clear_cache
      @@cache = {}
    end

    def cache_by(value, &blk)
      if cache.has_key?(value) then cache[value]
      else blk.call(value)
      end
    end
  end

  class Person
    extend Cached

    attr_accessor :nsid, :username, :realname, :location

    alias id nsid

    #
    # `Pickr::Person.new(args) -> Pickr::Photo`
    #
    # `args` - a hash containing arguments for building
    # `Pickr::Person` instances, the arguments are specified below:
    #   
    #   `:nsid`     - Flickr user id (required)
    #   `:username` - Flickr username (optional)
    #   `:realname` - Flickr user's real name (optional)
    #   `:location` - Flickr user's location (optional)
    #
    # Example:
    #   `Pickr::Person.new(:nsid => 99999999@N99)`
    #
    def initialize(args)
      @nsid     = args[:nsid] || raise(Error, "nsid is required")
      @username = args[:username]
      @realname = args[:realname].to_s
      @locaton  = args[:location].to_s
    end

    #
    # `Pickr::Person#username(opt) -> String`
    #
    # Returns username string if opt equals `:urlencoded`
    # then the string will be returned using URL escaping
    #
    # Example:
    #   `@person.username(:urlencoded)`
    #
    def username(opt=nil)
      if opt == :urlencoded
        ::URI.escape(@username)
      else
        @username
      end
    end

    #
    # `Pickr::Person.get(username) -> Pickr::Person`
    #
    # Factory method--fetches person information from Flickr
    # and builds a `Pickr::Person` instance. A `Pickr::Error`
    # is raised if communcation with the Flickr API fails.
    #
    # `username` - a Flickr users NSID or valid username
    #
    # Examples:
    #   `Pickr::Person.get('99999999@N00')`
    #   `Pickr::Person.get('some user name')`
    #
    def self.get(username)
      cache_by :"person-#{username}" do |k|
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

        args = { :nsid => id, :username => username }

        if info.respond_to?(:realname) && info.respond_to?(:location)
          args.merge!(:realname => info.realname, :location => info.location)
        end

        cache[k] = new(args)
      end
    end

    #
    # `Pickr::Person#gallery -> Pickr::Gallery`
    #
    # Returns a `Pickr::Gallery` instance based on photos
    # associated with `@nsid`.
    #
    # Example:
    #   `@person.gallery`
    #
    def gallery
      @gallery ||= Gallery.get(@nsid)
    end
  end

  class PhotoSet
    extend Cached

    attr_reader   :id, :description, :photos, :primary_photo_id  
    attr_accessor :title

    #
    # `Pickr::PhotoSet.new(info, photos=[]) -> Pickr::PhotoSet`
    #
    # `info`   - a `FlickRaw::Response` instance representing
    #            an Flickr photoset's information
    # `photos` - a `FlickRaw::Response` instance representing
    #            the photos of a photoset
    #
    def initialize(info, photos=[])
      @set              = info
      @id               = info.id
      @user_id          = info.respond_to?(:owner) && info.owner
      @title            = info.title
      @description      = info.description
      @photos           = construct_photos(photos)
      @primary_photo_id = info.primary
    end
  
    private
    
    def construct_photos(photos)
      photos.map do |p|
        Photo.new(
          :id     => p.id,
          :nsid   => @user_id,
          :title  => p.title,
          :server => p.server,
          :secret => p.secret
        )
      end
    end

    public
  
    #
    # `Pickr::PhotoSet#primary_photo -> Pickr::Photo`
    #
    # Returns a `Pickr::Photo` representing a photosets
    # primary photo.
    #
    # Example:
    #   @photoset.primary_photo
    #
    def primary_photo
      @primary_photo ||= 
        Photo.new(
          :id     => @set.primary,
          :title  => @set.title,
          :server => @set.server,
          :secret => @set.secret,
          :nsid   => @user_id
        )
    end
  
    #
    # `Pickr::PhotoSet.get(id) -> Pickr::PhotoSet`
    #
    # Factory method--fetches photoset information from Flickr
    # and builds a `Pickr::PhotoSet` instance. A `Pickr::Error`
    # is raised if communication with the Flickr API fails.
    #
    # `id` - a Flickr a photoset id
    #
    # Example:
    #   `Pickr::PhotoSet.get('131095211232')`
    #
    def self.get(id)
      cache_by :"photoset-#{id}" do |k|
        begin
          set  = flickr.photosets.getPhotos :photoset_id => id
          info = flickr.photosets.getInfo   :photoset_id => id
        rescue
          raise Error, "Couldn't retrieve photoset #{id}"
        end
        cache[k] = new(info, set.photo)
      end
    end
    
    #
    # `Pickr::PhotoSet#url -> String`
    #
    # Returns a `String` representing a photosets
    # URL on Flickr
    #
    # Example:
    #   `@photoset.url`
    #
    def url
      "#{FLICKR_PHOTO_URL}/#{@user_id}/sets/#{@id}"
    end
  end
  
  class Photo
    extend Cached

    attr_reader   :title, :nsid
    attr_accessor :id, :secret, :server
  
    #
    # `Pickr::Photo.new(args) -> Pickr::Photo`
    #
    # args - a hash containing arguments for building
    # `Pickr::Photo` instances, the arguments are specified below:
    #   
    #   `:id`     - Flickr photo id (required)
    #   `:server` - Flickr server id (required) 
    #   `:secret` - Flickr secret id (required)
    #   `:nsid`   - Flickr user id (optional)
    #   `:title`  - photo title (optional)
    #
    def initialize(args)
      @id      = args[:id]     || raise(Error, "id is required")
      @server  = args[:server] || raise(Error, "server is required")
      @secret  = args[:secret] || raise(Error, "secret is required")
      @user_id = args[:nsid]
      @title   = args[:title] != '' ? title : "Untitled"
    end

    #
    # `Pickr::Photo.get(id) -> Pickr::Photo`
    #
    # Factory method--fetches photo information from Flickr
    # and builds `Pickr::Photo` instance. A `Pickr::Error`
    # is raised if communication fails with the Flickr API.
    #
    # `id` - the photo's Flickr id
    #
    def self.get(id)
      cache_by :"photo-#{id}" do |k|
        begin
          photo = flickr.photos.getInfo :photo_id => id
        rescue
          raise Error, "Couldn't retrieve photo #{id}"
        end

        user_id = photo.respond_to?(:owner) && photo.owner.respond_to?(:nsid) && photo.owner.nsid

        cache[k] = new(
          :id     => id,
          :title  => photo.title,
          :server => photo.server,
          :secret => photo.secret,
          :nsid   => user_id
        )
      end
    end
  
    #
    # `Pickr::Photo#url(type=:medium) -> String`
    #
    # Generates url for photo of type:
    #
    #   - `:square`
    #   - `:square75`
    #   - `:square150`
    #   - `:thumbnail`
    #   - `:original`
    #   - `:medium`
    #   - `:page`
    #   - `:lightbox`
    # 
    def url(type=:medium)
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

      # alias for `:square`
      sizes[:square75] = sizes[:square]
      
      unless sizes.keys.include?(type.to_sym)
        raise Error, "'#{type}' is not a valid URL type" 
      end

      sizes[type.to_sym]
    end
  end # Photo

  class Gallery
    extend Cached

    attr_reader :user_id, :sets

    #
    # `Pickr::Gallery.new(nsid, sets) -> Pickr::Gallery`
    #
    # `nsid` - the NSID of a Flickr user
    # `sets` - a `FlickRaw::Response` instance representing
    #          the photosets of a Flickr user
    #
    def initialize(nsid, sets)
      @user_id = nsid
      @sets    = sets.map { |s| PhotoSet.new(s) }
    end
  
    #
    # `Pickr::Gallery.get(nsid) -> Pickr::Gallery`
    #
    # Factory method for building `Pickr::Gallery`
    # instances; A `Pickr::Error` is raised if 
    # communication with the Flickr API fails.
    #
    # `nsid` - the NSID of a Flickr user
    #
    def self.get(nsid)
      cache_by :"gallery-#{nsid}" do |k|
        begin
          sets = flickr.photosets.getList :user_id => nsid
        rescue
          raise Error, "Couldn't retrieve photosets for user #{nsid}"
        end
        cache[k] = new(nsid, sets)
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
