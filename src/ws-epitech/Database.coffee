##
# Copyright 2012 Jerome Quere < contact@jeromequere.com >.
#
# This file is part of Ws-epitech.
#
# Ws-epitech is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ws-epitech is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ws-epitech.If not, see <http://www.gnu.org/licenses/>.
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