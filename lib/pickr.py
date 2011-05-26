#
# = Pickr - A Gallery tool for Photographers
# These classes represent are an abstration away from the Flickr API.
# They provide methods for creating a gallery of photos for selecting
# and submitting to the photographer.
#

import yaml
import json
import flickrapi
import os.path as path

from pprint import pprint as pp
from xml.etree import ElementTree as xml

f = open(path.dirname(path.abspath(__file__)) + '/../config.yml', 'r')
config = yaml.load(f)
f.close()

FLICKR_PHOTO_URL    = "http://www.flickr.com/photos"
FLICKR_STATIC_URL   = "http://farm5.static.flickr.com"

# TODO: make these optionally configurable in a db also
API_KEY             = config['flickr_api_key']
AUTH_TOKEN          = config['auth_token']
USER_ID             = config['user_id']
PRIMARY_PHOTO_CACHE = config['primary_photo_cache']
GALLERY_TITLE       = config['gallery_title']
SET_PHOTO_SIZE      = config['set_photo_size']

flickr       = flickrapi.FlickrAPI(API_KEY, format='etree')
flickr.cache = flickrapi.SimpleCache(timeout=5, max_entries=100)

def memoize(f):
	cache = {}
	def memf(*x):
		if x not in cache:
			cache[x] = f(*x)
		return cache[x]
	return memf

class PhotoSet:
	def __init__(self, id):
		s = flickr.photosets_getPhotos(photoset_id=id)
		i = flickr.photosets_getInfo(photoset_id=id)
		return self.parse(i, s)

	def parse(self, i, s=None):
		if s:
			photos      = s.find('photoset').findall('photo')
			self.photos = map(lambda p: Photo().parse(p), photos)

		set                   = i.find('photoset')
		self.title            = set.find('title').text
		self.description      = set.find('description').text
		self.id               = set.attrib['id']
		self.primary_photo_id = set.attrib['primary']

		return self

	@memoize
	def primary_photo(self):
		return Photo(self.set['primary'], self.set['title'], \
								 self.set['server'],  self.set['secret'])

	def url(self):
		return "{0}/{1}/sets/{2}".format(FLICKR_PHOTO_URL, USER_ID, self.id)

	def to_hash(self):
		return { self.id : primary_photo().to_square_url() }

class Photo:
	def __init__(self, id='', title='', server='', secret=''):
		self.id     = id
		self.title  = title
		self.server = server
		self.secret = secret
		self.url    = None

	def get(self, id):
		rsp   = flickr.photos_getInfo(photo_id=id)
		photo = rsp.find('photo')
		return self.parse(photo)

	def parse(self, photo):
		self.title  = photo.attrib['title']
		if self.title == '':
			self.title = 'Untitled'
		self.id     = photo.attrib['id']
		self.server = photo.attrib['server']
		self.secret = photo.attrib['secret']
		return self

	# Generates url for photo of type:
	# - square
	# - thumbnail
	# - original
	# - medium
	# - page
	# - lightbox
	def to_url(self, type=SET_PHOTO_SIZE):
		if self.url:
			return self.url # allows us to override url generation

		url_str = {
			'square'    : self.to_square_url,
			'thumbnail' : self.to_thumbnail_url,
			'original'  : self.to_original_url,
			'medium'    : self.to_medium_url,
			'page'      : self.to_page_url,
			'lightbox'  : self.to_lightbox_url,
		}.get(type, self.to_medium_url)

		return url_str()

	@memoize
	def to_base_url(self):
		return "{0}/{1}/{2}_{3}".format(FLICKR_STATIC_URL, self.server, self.id, self.secret)

	@memoize
	def to_square_url(self):
		return "{0}_s.jpg".format(self.to_base_url())

	@memoize
	def to_thumbnail_url(self):
		return "{0}_t.jpg".format(self.to_base_url())

	@memoize
	def to_original_url(self):
		return "{0}.jpg".format(self.to_base_url())

	@memoize
	def to_medium_url(self):
		return "{0}_m.jpg".format(self.to_base_url())

	@memoize
	def to_page_url(self):
		return "{0}/{1}/{2}".format(FLICKR_PHOTO_URL, USER_ID, self.id)

	@memoize
	def to_lightbox_url(self):
		return "{0}/lightbox".format(self.to_page_url())

class Gallery:
	def __init__(self, user_id=USER_ID):
		sets = flickr.photosets_getList(user_id=user_id)
		self.user_id = user_id
		pp(xml.dump(sets))
		self.sets    = map(lambda s: PhotoSet().parse(s), sets)
