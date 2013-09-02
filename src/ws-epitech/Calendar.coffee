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

moment = require('moment');

class Event
	constructor: (@title, begin, end) ->
		@begin = moment(begin)
		@end = moment(end)
		@begin.utc();
		@end.utc();

	toVEvent: () ->
		return "BEGIN:VEVENT\nDTSTART:#{@begin.format('YYYYMMDDTHHmmss[Z]')}\nDTEND:#{@end.format('YYYYMMDDTHHmmss[Z]')}\nSUMMARY:#{@title}\nEND:VEVENT";

class Calendar
	constructor: () ->
		@events = []

	addEvent: (title, start, end) ->
		@events.push(new Event(title, start, end));

	toVCal: () ->
		str = "BEGIN:VCALENDAR\nVERSION:2.0\n";
		for event in @events
			str = "#{str}#{event.toVEvent()}\n";
		str = "#{str}END:VCALENDAR\n";
		return str;

module.exports = Calendar;