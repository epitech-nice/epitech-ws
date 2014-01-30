##
#The MIT License (MIT)
#
# Copyright (c) 2013 Jerome Quere <contact@jeromequere.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
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