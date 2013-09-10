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

class Logger

	@ERROR_LEVEL = 1
	@WARN_LEVEL = 2
	@INFO_LEVEL = 3
	@DEBUG_LEVEL = 4

	constructor: () ->
		@level = Logger.INFO_LEVEL;
		for arg in process.argv
			if (arg == '-v')
				@level = Logger.DEBUG_LEVEL;

	error: (args...) ->
		if (@_shoodPrint(Logger.ERROR_LEVEL))
			str = "ERROR  #{@_getDate()} - #{@_getStr(args)}"
			console.log(str);

	warn: (args...) ->
		if (@_shoodPrint(Logger.WARN_LEVEL))
			str = "WARN   #{@_getDate()} - #{@_getStr(args)}"
			console.log(str);

	info: (args...) ->
		if (@_shoodPrint(Logger.INFO_LEVEL))
			str = "INFO   #{@_getDate()} - #{@_getStr(args)}"
			console.log(str);

	debug: (args...) ->
		if (@_shoodPrint(Logger.DEBUG_LEVEL))
			str = "DEBUG  #{@_getDate()} - #{@_getStr(args)}"
			console.log(str);

	_shoodPrint: (level) ->
		return @level >= level;

	_getDate: () ->
		date = new Date()
		str = "#{date.getFullYear()}-#{@_2digits(date.getMonth() + 1)}-#{@_2digits(date.getDate())}"
		str = "#{str} #{@_2digits(date.getHours())}:#{@_2digits(date.getMinutes())}:#{@_2digits(date.getSeconds())}"
		return str;

	_getStr: (args) ->
		str = '';
		for arg in arguments
			str = "#{str}#{arg}"
		return str;

	_2digits: (nb) ->
		if nb >= 10 then return nb
		return "0#{nb}";

module.exports = new Logger();