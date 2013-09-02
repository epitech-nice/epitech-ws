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

Config = require('./Config.coffee');
HttpClient = require('./HttpClient.coffee');

class IntraCommunicator

	constructor: () ->
		@login = Config.get('login');
		@password = Config.get('password');
		@sid = null;

	connect: () ->
		p = HttpClient.post("https://intra.epitech.eu", "login=#{encodeURIComponent(@login)}&password=#{encodeURIComponent(@password)}");
		p = p.then (data) =>
			if (data.res.statusCode != 302) then throw "IntraCommunicator - Bad logins"
			for cookie in data.res.headers['set-cookie']
				cookie = cookie.split("; ")[0];
				cookie = cookie.split("=");
				if (cookie[0] == 'PHPSESSID')
					@sid = cookie[1];
		return p;


	getCalandarEvents: (id) ->
		return	@_getJson("https://intra.epitech.eu/planning/#{id}/events?format=json");

	_getJson: (url) ->
		p = HttpClient.get(url, {Cookie:"PHPSESSID=#{@sid}"});
		return p.then (data) ->
			jsonStr = data.data;
			jsonStr = jsonStr.replace("// Epitech JSON webservice ...", "");
			return JSON.parse(jsonStr);


module.exports = IntraCommunicator;