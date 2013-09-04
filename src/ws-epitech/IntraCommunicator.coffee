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

Cache = require('./Cache.coffee');
Calendar = require('./Calendar.coffee');
Config = require('./Config.coffee');
HttpClient = require('./HttpClient.coffee');
moment = require('moment-timezone');
UrlCache  = require('./UrlCache.coffee');

class IntraCommunicator

	constructor: (database) ->
		@login = Config.get('login');
		@password = Config.get('password');
		@sid = null;
		@urlCache = new UrlCache(database);

	connect: () ->
		p = HttpClient.post("https://intra.epitech.eu", "login=#{encodeURIComponent(@login)}&password=#{encodeURIComponent(@password)}");
		p = p.then (data) =>
			if (data.res.statusCode != 302) then throw "IntraCommunicator - Bad logins"
			for cookie in data.res.headers['set-cookie']
				cookie = cookie.split("; ")[0];
				cookie = cookie.split("=");
				if (cookie[0] == 'PHPSESSID')
					@sid = cookie[1];
		return p;


	intraToUTCTime: (dateString, timezoneFrom) ->
		offset = moment(new Date(dateString)).tz(timezoneFrom).zone() - new Date().getTimezoneOffset();
		return moment(new Date(dateString)).add('m', offset).toDate();



	getCalandar: (id) ->
		p = @_getJson("https://intra.epitech.eu/planning/#{id}/events?format=json");
		return p.then (json) =>
			cal = new Calendar();
			for activity in json.activities
				start = @intraToUTCTime(activity.start, "Europe/Paris");
				end = @intraToUTCTime(activity.end, "Europe/Paris");
				cal.addEvent(activity.title, start, end);
			return cal


	getNsLog: (login, start, end) ->
		@_getCompleteNsLog(login).then (report) ->
			partialReport = {};
			start = if (start?) then moment(start).format("YYYY-MM-DD") else null;
			end = if (end?) then moment(end).format("YYYY-MM-DD") else null;
			for date, day of report
				if ((!start? || date >= start) and (!end? || date <= end))
					partialReport[date] = day;
			return partialReport;


	_getCompleteNsLog: (login) ->
		return Cache.find("INTRA.NETSOUL.#{login}"). then (cached) =>
			if (cached?) then return cached;
			return @_getJson("https://intra.epitech.eu/user/#{login}/netsoul?format=json").then (json) ->
				report = {};
				for rawDay in json
					day = {school:rawDay[1], idleSchool:rawDay[2], out:rawDay[3], idleOut:rawDay[4], avg:rawDay[5]};
					date = moment.unix(rawDay[0]).format("YYYY-MM-DD");
					report[date] = day;
				Cache.insert("INTRA.NETSOUL.#{login}", report, moment().add('h', 2));
				return report;


	_get: (url) ->
		p = @urlCache.find(url).then (data) =>
			if (data?) then return data;
			p = HttpClient.get(url, {Cookie:"PHPSESSID=#{@sid}"}).then (res) =>
				if (res.res.statusCode == 403)
					return @connect().then () => @_get(url)
				@urlCache.insert(url, res.data, moment().add('m', 15).toDate());
				return res.data;

	_getJson: (url) ->
		p = @_get(url)
		return p.then (data) ->
			jsonStr = data;
			jsonStr = jsonStr.replace("// Epitech JSON webservice ...", "");
			return JSON.parse(jsonStr);



module.exports = IntraCommunicator;