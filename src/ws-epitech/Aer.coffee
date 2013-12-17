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

Cache = require('./Cache.coffee');
HttpClient = require('./HttpClient.coffee');
moment = require('moment');

class Aer
	@getDuty: () ->
		Aer._loadFromGoogle().then (data) ->
			return data;

	@_loadFromGoogle: () ->
		HttpClient.getJson("https://script.google.com/macros/s/AKfycbx87n3-T3SD59Pj_qUTQmTZaMfq4IAK_kQ_TIkXcQqC91Hx2dI/exec").then (data) ->
			duty = {};
			for week in data
				date = moment(week[0]).utc()
				duty[date.format("YYYY-MM-DD")] = [week[2], week[3]];
				duty[date.add('d', 1).format("YYYY-MM-DD")] =  [week[4], week[5]];
				duty[date.add('d', 1).format("YYYY-MM-DD")] =  [week[6], week[7]];
				duty[date.add('d', 1).format("YYYY-MM-DD")] =  [week[8], week[9]];
				duty[date.add('d', 1).format("YYYY-MM-DD")] =	[week[10], week[11]];
				duty[date.add('d', 1).format("YYYY-MM-DD")] =	[week[12], week[13]];
				duty[date.add('d', 1).format("YYYY-MM-DD")] =	[week[14], week[15]];
			return duty;

module.exports = Aer;
