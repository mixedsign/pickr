import time

def memoize(f):
	cache = {}
	def memf(*x):
		if x not in cache:
			cache[x] = f(*x)
		return cache[x]
	return memf

class Test:
		@memoize
		def slow(self, val):
				time.sleep(3)
				return val


import os.path
print os.path.dirname(os.path.abspath(__file__))
