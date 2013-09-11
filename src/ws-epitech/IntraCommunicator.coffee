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
			start = if (start?) then moment(start).tz("Europe/Paris").format("YYYY-MM-DD") else null;
			end = if (end?) then moment(end).tz("Europe/Paris").format("YYYY-MM-DD") else null;
			for date, day of report
				if ((!start? || date >= start) and (!end? || date <= end))
					partialReport[date] = day;
			return partialReport;

	getCityUsers: (city) ->
		return Cache.find("INTRA.ALL_USERS.#{city}"). then (cached) =>
			if (cached?) then return cached;
			return @_getCityUserOffset(city, 0). then (data) =>
				return Cache.insert("INTRA.ALL_USERS.#{city}", data, moment().add('d', 2).toDate()).then () ->
					return data;


	getCityModules: (city) ->
		return Cache.find("INTRA.ALL_MODULES.#{city}"). then (cached) =>
			if (cached?) then return cached;
			return @_getJson("https://intra.epitech.eu/course/filter?format=json&location=#{city}").then (data) =>
				modules = []
				for module in data
					m = {};
					m.title = module.title;
					m.semester = module.semester;
					m.scolaryear = module.scolaryear;
					m.moduleCode = module.code;
					m.instanceCode = module.codeinstance;
					m.credits = module.credits;
					modules.push(m)
				return Cache.insert("INTRA.ALL_MODULES.#{city}", modules, moment().add('d', 2).toDate()).then () ->
					return modules;


	getModuleRegistred: (year, moduleCode, instanceCode) ->
		@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}/registered?format=json").then (data) ->
			students = {}
			for student in data
				students[student.login] = {grade: student.grade, credits: student.credits}
			return students;

	getUser: (login) ->
		@_getJson("https://intra.epitech.eu/user/#{login}/?format=json").then (data) =>
			user = {};
			user.login = data.login;
			user.lastname = data.lastname;
			user.firstname = data.firstname;
			user.picture = data.picture;
			user.promo = data.promo;
			user.semester = data.semester;
			user.uid = data.uid;
			user.location = data.location;
			user.credits = user.possibleCredits = user.failedCredits = 0;
			return @getUserModules(login).then (modules) ->
				for module in modules
					user.credits += if (module.grade != "-" and module.grade != "Echec") then module.credits else 0;
					user.possibleCredits += if (module.grade == "-") then module.credits else 0;
					user.failedCredits += if (module.grade == "Echec") then module.credits else 0;
				return user;

	getUserModules: (login) ->
		return Cache.find("INTRA.USER.#{login}.MODULES").then (cached) =>
			if (cached?) then return cached;
			return @_getJson("https://intra.epitech.eu/user/#{login}/notes?format=json").then (data) =>
				modules = [];
				for module in data.modules
					m = {};
					m.scolaryear = module.scolaryear;
					m.title = module.title;
					m.grade = module.grade;
					m.credits = module.credits;
					m.semester = module.semester;
					m.moduleCode = module.codemodule;
					m.instanceCode = module.codeinstance;
					modules.push(m);
				return Cache.insert("INTRA.USER.#{login}.MODULES", modules, moment().add('d', 2).toDate()).then () ->
					return modules;

	_getCityUserOffset: (city, offset) ->
		users = []
		return @_getJson("https://intra.epitech.eu/user/filter/user?format=json&year=2013&active=true&location=#{city}&offset=#{offset}").then (data) =>
				for user in data.items
					users.push({login:user.login, firstname:user.prenom, lastname:user.nom});
				if (users.length + offset < data.total)
					return @_getCityUserOffset(city, users.length).then (users2) -> return users.concat(users2)
				return users;

	_getCompleteNsLog: (login) ->
		return Cache.find("INTRA.NETSOUL.#{login}"). then (cached) =>
			if (cached?) then return cached;
			return @_getJson("https://intra.epitech.eu/user/#{login}/netsoul?format=json").then (json) ->
				report = {};
				for rawDay in json
					day = {school:rawDay[1], idleSchool:rawDay[2], out:rawDay[3], idleOut:rawDay[4], avg:rawDay[5]};
					date = moment.unix(rawDay[0]).tz("Europe/Paris").format("YYYY-MM-DD");
					report[date] = day;
				Cache.insert("INTRA.NETSOUL.#{login}", report, moment().add('h', 2).toDate());
				return report;

	_get: (url) ->
		p = @urlCache.find(url).then (data) =>
			if (data?) then return data;
			p = HttpClient.get(url, {headers:{Cookie:"PHPSESSID=#{@sid}"}}).then (res) =>
				if (res.res.statusCode == 403)
					return @connect().then () => @_get(url)
				@urlCache.insert(url, res.data, moment().add('m', 15).toDate());
				return res.data;

	_getJson: (url) ->
		p = @_get(url)
		return p.then (jsonStr) ->
			jsonStr = jsonStr.replace("// Epitech JSON webservice ...", "");
			data = JSON.parse(jsonStr);
			if (data.error?) then throw "Intra: #{data.error}"
			return data;

module.exports = IntraCommunicator;