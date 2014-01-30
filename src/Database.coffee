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

MongoClient = require('mongodb').MongoClient
When = require('when');

class Database
	constructor: () ->

	run : () ->
		deffer = When.defer()
		MongoClient.connect 'mongodb://127.0.0.1:27017/ws-epitech', (err, db) =>
			if (err?) then return deffer.reject(err);
			@db = db;
			deffer.resolve(true);
		return deffer.promise;

	find: (collection, search) ->
		defer = When.defer();
		collection = @db.collection(collection);
		collection.find(search).toArray (err, results) ->
			if (err) then defer.reject(err);
			defer.resolve(results);
		return defer.promise;

	insert: (collection, data) ->
		defer = When.defer();
		collection = @db.collection(collection);
		collection.insert data, (err, docs) ->
			if (err)
				defer.reject(err)
				return;
			defer.resolve(docs);
		return defer.promise;


module.exports = Database;