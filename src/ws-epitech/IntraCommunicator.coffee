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
Utils = require('./Utils.coffee');
When = require('when');

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


	getNsReport: (login, start, end) ->
		promises = @getNsLog(login, start, end).then (nsLog) =>
			res = {school:0, idleSchool:0, out:0, idleOut:0};
			for date, log of nsLog
				res.school += log.school;
				res.idleSchool += log.idleSchool;
				res.out += log.out;
				res.idleOut += log.out;
			return res;

	getCityUsers: (city) ->
		return Cache.find("INTRA.ALL_USERS.#{city}"). then (cached) =>
			if (cached?) then return cached;
			return @_getCityUserOffset(city, 0). then (data) =>
				return Cache.insert("INTRA.ALL_USERS.#{city}", data, moment().add('d', 2).toDate()).then () ->
					return data;


	getCityModules: (city, filters) ->
		end = Config.get('scolar-year');
		begin = end - 3;
		scolaryear = ""
		for year in [begin..end]
			scolaryear = "#{scolaryear}&scolaryear[]=#{year}"
		return @_getJson("https://intra.epitech.eu/course/filter?format=json&location=#{city}&#{scolaryear}").then (data) =>
			modules = []
			for module in data
				m = {};
				m.title = module.title;
				m.semester = module.semester;
				m.scolaryear = module.scolaryear;
				m.moduleCode = module.code;
				m.instanceCode = module.codeinstance;
				m.credits = module.credits;
				if (Utils.match(m, filters)) then modules.push(m)
			return modules;


	getModuleRegistred: (year, moduleCode, instanceCode) ->
		return Cache.find("INTRA.MODULE.#{year}.#{moduleCode}.#{instanceCode}.REGISTERED").then (cached) =>
			if (cached?) then return cached;
			@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}/registered?format=json").then (data) ->
				students = {}
				for student in data
					students[student.login] = {grade: student.grade, credits: student.credits}
				return Cache.insert("INTRA.MODULE.#{year}.#{moduleCode}.#{instanceCode}.REGISTERED", students, moment().add('d', 1).toDate()).then () ->
					return students;

	getModulePresent: (year, moduleCode, instanceCode) ->
		return Cache.find("INTRA.MODULE.#{year}.#{moduleCode}.#{instanceCode}.PRESENT").then (cached) =>
			if (cached?) then return cached;
			@_get("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}/present?format=json").then (data) ->
				regexp = new RegExp('className": "notes",[\\s\\S]*"items": (\\[.*\\]),[\\s\\S]+"columns":');
				res = regexp.exec(data);
				students = JSON.parse(res[1]);
				data = {}
				for s in students
					data[s.login] = {total_registered: s.total_registered, total_present: s.total_present, total_absent: s.total_absent};
				return Cache.insert("INTRA.MODULE.#{year}.#{moduleCode}.#{instanceCode}.PRESENT", data, moment().add('d', 1).toDate()).then () ->
					return data;


	getModuleProject: (year, moduleCode, instanceCode) ->
		return Cache.find("INTRA.MODULE.#{year}.#{moduleCode}.#{instanceCode}").then (cached) =>
			if (cached?) then return cached;
			@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}?format=json").then (data) ->
				projects = [];
				activities = data.activites
				for activity in activities
					if (activity.is_projet)
						projects.push({name: activity.title, start: activity.start, end: activity.end});
				return Cache.insert("INTRA.MODULE.#{year}.#{moduleCode}.#{instanceCode}", projects, moment().add('d', 1).toDate()).then () ->
					return projects;

	getUser: (login) ->
		return Cache.find("INTRA.USER.#{login}").then (cached) =>
			@_getJson("https://intra.epitech.eu/user/#{login}/?format=json").then (data) =>
				user = {};
				user.login = data.login;
				if (user.lastname and user.firstname)
					user.lastname = data.lastname;
					user.firstname = data.firstname;
				else
					[user.firstname, user.lastname] = data.title.split(" ", 2);
				user.picture = data.picture;
				user.promo = if (data.promo?) then (data.promo) else (0);
				user.semester = if (data.semester?) then (data.semester) else (0);
				user.uid = data.uid;
				user.location = data.location;
				user.credits = user.possibleCredits = user.failedCredits = 0;
				return @getUserModules(login).then (modules) ->
					for module in modules
						user.credits += if (module.grade != "-" and module.grade != "Echec") then module.credits else 0;
						user.possibleCredits += if (module.grade == "-") then module.credits else 0;
						user.failedCredits += if (module.grade == "Echec") then module.credits else 0;
					return Cache.insert("INTRA.USER.#{login}", user, moment().add('d', 1).toDate()).then () ->
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
				p = for user in data.items
					@getUser(user.login).then (data) =>
						users.push(data);
				if (p.length + offset < data.total)
					p.push(@_getCityUserOffset(city, p.length + offset).then (users2) ->
						users = users.concat(users2)
					)
				return When.all(p).then () -> return users;

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