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