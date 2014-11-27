##
#The MIT License (MIT)
#
# Copyright (c) 2013 Jerome Quere <contact@jeromequere.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
##

When = require('when')
dirty = require('dirty')
Logger = require('./Logger.coffee')

class Database
	constructor: (@path) ->
		@db = null

	start: () ->
		deffer = When.defer()
		@db = dirty(@path);
		@db.on 'load', () ->
			deffer.resolve(true);
		return deffer.promise;

	find: (key) ->
		defer = When.defer();
		row = @db.get key
		if !row
			defer.resolve(null);
		else
			if (row.ttl?)
				ttl = new Date(row.ttl);
				now = new Date();
				if (ttl < now)
					@delete(key);
					row.data = null;
			defer.resolve(row.data);
		return defer.promise;

	delete: (key) -> @db.set(key, undefined);

	insert: (key, value, ttl) ->
		defer = When.defer();
		@db.set(key, {data: value, ttl: ttl});
		defer.resolve(value);
		return defer.promise;

	stop: () ->
		if (@db) then @db.close()

module.exports = Database;
