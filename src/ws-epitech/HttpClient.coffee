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
When = require('when')

class HttpClient
	@request: (options, post) ->
		defer = When.defer()
		tool = http;
		if (options.url.protocol == 'https:')
			tool = https;
		options.url.method = if (options.method?) then	options.method else "GET";
		req = tool.request options.url, (res) =>
			data = new Buffer(0);
			resolver = defer.resolver
			res.on 'data', (chunk) ->
				data = Buffer.concat([data, chunk]);
			res.on 'end', () =>
				Logger.info("#{options.method} #{Url.format(options.url)}");
				if (res.headers.location?)
					options.url = Url.parse(res.headers.location);
					if (options.url.protocol? and options.url.host? and options.url.path?)
						resolver.resolve(@request(options, post));
						return;
				if (options.encoding? and options.encoding != "utf8")
					data = new Iconv(options.encoding, 'UTF-8').convert(data);
				resolver.resolve({res:res, data:data.toString('utf8')});

		req.on 'error', () =>
			defer.resolver.reject("Error - HttpClient - Can't load #{url}");
		if (options.headers?)
			for header,value of options.headers
				req.setHeader(header, value)
		if (post?)
			req.setHeader("Content-Length", post.length);
			req.setHeader("Content-Type", "application/x-www-form-urlencoded");
			req.write(post);
		req.end();
		return (defer.promise);

	@get: (url, options) ->
		options.url = Url.parse(url);
		options.method = "GET"
		return HttpClient.request(options);

	@getJson: (url, options) ->
		return @get(url, options).then (data) ->
			return JSON.parse(data.data);

	@post: (url, data, options) ->
		if (!options?) then options = {};
		options.url = Url.parse(url);
		options.method = "POST"
		options.headers;
		return HttpClient.request(options, data);


module.exports = HttpClient