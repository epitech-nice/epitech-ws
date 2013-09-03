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

http = require('http');
https = require('https');
Logger = require('./Logger.coffee');
Url = require('url');
When =require('when')

class HttpClient
	@request: (options, data, headers) ->
		defer = When.defer()
		tool = http;
		if (options.protocol == 'https:')
			tool = https;
		req = tool.request options, (res) =>
			data = ''
			resolver = defer.resolver
			res.setEncoding('utf8');
			res.on 'data', (chunk) ->
				data = "#{data}#{chunk}";
			res.on 'end', () ->
				Logger.info("#{options.method} #{Url.format(options)}");
				resolver.resolve({res:res, data:data});

		req.on 'error', () =>
			defer.resolver.reject("Error - HttpClient - Can't load #{url}");
		if (headers?)
			for header,value of headers
				req.setHeader(header, value)
		if (data?)
			req.setHeader("Content-Length", data.length);
			req.setHeader("Content-Type", "application/x-www-form-urlencoded");
			req.write(data);
		req.end();
		return (defer.promise);

	@get: (url, headers) ->
		options = Url.parse(url);
		options.method = "GET"
		return HttpClient.request(options, null, headers);

	@post: (url, data, headers) ->
		options = Url.parse(url);
		options.method = "POST"
		options.headers = headers;
		return HttpClient.request(options, data);


module.exports = HttpClient