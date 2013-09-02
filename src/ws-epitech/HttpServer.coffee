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

EventEmmiter = require('events').EventEmitter
Http = require('http');
HttpRequest = require('./HttpRequest.coffee')
HttpResponse = require('./HttpResponse.coffee')

class HttpServer extends EventEmmiter
	constructor: (@port) ->
		@server = Http.createServer(@onRequest)

	run: () ->
		@server.listen(@port)

	onRequest: (request, response) =>
		req = new HttpRequest(request)
		res = new HttpResponse(response)
		@emit('get', req, res)

module.exports = HttpServer