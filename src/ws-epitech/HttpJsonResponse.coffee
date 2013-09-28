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

class HttpJsonErrors
	@errors = {}
	@errors[1] = "Bad Parameters";
	@errors[404] ="The url you requested don't exit"
	@errors[500] = "Server error"
	@get: (code) ->
		if (HttpJsonErrors.errors[code]?) then return HttpJsonErrors.errors[code];
		return HttpJsonErrors.errors[500];


class HttpJsonResponse
	@error: (code, msg) ->
		if (!msg?) then msg = HttpJsonErrors.get(code)
		return {code: code, msg: msg};

	@success: (data) ->
		return {code: 200, msg: "Success", data: data};

module.exports = HttpJsonResponse;