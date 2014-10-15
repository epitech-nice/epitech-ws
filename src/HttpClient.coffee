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
				Logger.debug("#{options.method} #{Url.format(options.url)}");
				if (res.headers.location?)
					url = Url.parse(res.headers.location);
					if (url.path != options.url.path)
						for key, value of url
							if (url[key]?) then options.url[key] = value;
						resolver.resolve(@request(options, post));
						return;
				if (options.encoding? and options.encoding != "utf8")
					data = new Iconv(options.encoding, 'UTF-8').convert(data);
				resolver.resolve({res:res, data:data.toString('utf8')});

		req.on 'error', () =>
			defer.resolver.reject("Error - HttpClient - Can't load #{Url.format(options.url)}");
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
		if (!options)
			options = {}
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
