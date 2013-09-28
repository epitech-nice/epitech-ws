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

class HttpResponse
	constructor: (@response) ->

	setMime: (mime) ->
		@response.setHeader("Content-Type", mime);

	endJSON: (obj) ->
		@setMime("application/json");
		@response.write(JSON.stringify(obj));
		@response.end();

	end: (@message) ->
		@response.write(@message);
		@response.end()

module.exports = HttpResponse