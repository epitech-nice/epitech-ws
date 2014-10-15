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
				duty[date.add(1, 'd').format("YYYY-MM-DD")] =  [week[4], week[5]];
				duty[date.add(1, 'd').format("YYYY-MM-DD")] =  [week[6], week[7]];
				duty[date.add(1, 'd').format("YYYY-MM-DD")] =  [week[8], week[9]];
				duty[date.add(1, 'd').format("YYYY-MM-DD")] =	[week[10], week[11]];
				duty[date.add(1, 'd').format("YYYY-MM-DD")] =	[week[12], week[13]];
				duty[date.add(1, 'd').format("YYYY-MM-DD")] =	[week[14], week[15]];
			return duty;

module.exports = Aer;
