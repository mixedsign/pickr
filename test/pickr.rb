require 'lib/pickr'
require 'lib/pickr/helpers'
require 'test/unit'

require 'rubygems'

class TestPhoto < Test::Unit::TestCase
  def setup
    @photo = Pickr::Photo.get('5210606401')
  end

  def test_get_photo_type
    assert_instance_of Pickr::Photo, @photo, "result should be an instace of photo"
  end

  def test_page_url
    assert_equal "http://www.flickr.com/photos/26835295@N06/5210606401", @photo.url(:page),
      "the urls should be equal"
  end

  def test_lightbox_url
    assert_equal "http://www.flickr.com/photos/26835295@N06/5210606401/lightbox", @photo.url(:lightbox),
      "the urls should be equal"
  end
end

class TestPhotoSet < Test::Unit::TestCase
  
  def setup
    @set = Pickr::PhotoSet.get('72157624264693371')
  end

  def test_get_photoset_type
    assert_instance_of Pickr::PhotoSet, @set, "result should be an instace of Pickr::PhotoSet"
  end

  def test_primary_photo_default_photo
    photo = @set.primary_photo # starts thread to fetch image and returns a default image
    assert photo.respond_to?(:url), "default photo class is derived but has a 'url' method"
  end
end

class TestPerson < Test::Unit::TestCase
  def setup
    @person = Pickr::Person.get('drnewman')
  end

  def test_username
    assert_equal 'drnewman', @person.username
  end

  def test_nsid
    assert_equal '36602382@N00', @person.nsid
  end

  def test_type
    assert_instance_of Pickr::Person, @person, "should be an instance of Pickr::Person"
  end

  def test_gallery_type
    assert_instance_of Pickr::Gallery, @person.gallery, "should be and instance of Pickr::Gallery"
  end
end

class TestGallery < Test::Unit::TestCase
  def setup
    @person = Pickr::Person.get('msdama')
    @gallery = Pickr::Gallery.get(@person.nsid)
  end

  def test_sets
    assert !@gallery.sets.empty?, "sets should not be empty"
  end
end

class TestPosessiveHelper < Test::Unit::TestCase
  include Pickr::Helpers

  def setup
    @names = {
      'John'     => "John's",
      'Dave'     => "Dave's",
      'Sharron'  => "Sharron's",
      'Starbuck' => "Starbuck's",
      'Starz'    => "Starz'",
      'Status'   => "Status'"
    }
  end

  def test_names
    @names.each_pair do |k, v|
      assert_equal possessive(k), v, "possessive('#{k}') should equal #{v}"
    end
  end
end
