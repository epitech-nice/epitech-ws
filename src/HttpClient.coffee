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

http = require('http');
https = require('https');
Logger = require('./Logger.coffee');
Url = require('url');
When = require('when')
request = require('request');

class HttpClient
	@get: (url, options) ->
		if (!options)
			options = {}
		options.url = url;
		options.method = "GET"
		defer = When.defer();
		request options, (error, response, body) ->
			if (error?) then return defer.reject(error);
			defer.resolve({res: response, data: body});
		return defer.promise


	@getJson: (url, options) ->
		return @get(url, options).then (data) ->
			return JSON.parse(data.data);

	@post: (url, data, options) ->
		if (!options?) then options = {};
		options.url = url;
		options.method = "POST"
		options.form = data;
		defer = When.defer();
		request options, (error, response, body) ->
			if (error?) then return defer.reject(error);
			defer.resolve({res: response, data: body});
		return defer.promise


module.exports = HttpClient
