##
# Copyright 2012 Jerome Quere < contact@jeromequere.com >.
#
# This file is part of ws-epitech.
#
# ws-epitech is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ws-epitech is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ws-epitech.If not, see <http://www.gnu.org/licenses/>.
##

class Cache
	constructor: () ->

	find: (key) ->
		p = @db.find(@collection, {key:key})
		p.then (results) ->
			if (results.length == 0) then return null;
			return results[0].value;

	insert: (key, value, ttl) ->
		@db.insert(@collection, {key: key, value:value, ttl:ttl});

	setDb: (@db) ->
		@collection = "cache"

module.exports = new Cache();