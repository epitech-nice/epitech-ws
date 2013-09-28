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

fn = require('when/function')

class RouteManager
	constructor: () ->
		@routes = {}

	addRoute: (patern, callback, data = {}) ->
		vars = {}
		matches = patern.match(/\$([a-zA-Z]+)/g)
		if (matches?)
			i = 1
			for match in matches
				vars[i] = match.substr(1)
				i++;
			patern = patern.replace(/\$[a-zA-Z]+/g, '([a-zA-Z0-9_-]*)');
		@routes["^#{patern}$"] = {callback: callback, data: data, vars: vars};

	exec: (req, res) ->
		for patern, route of @routes
			data = {}
			matches = new RegExp(patern).exec(req.getUrl())
			if (matches?)
				for key, value of route['data']
					data[key] = value;
				for id, name of route.vars
					data[name] = matches[id]
				return fn.call(route.callback, req, res, data)
		return null;

module.exports = RouteManager