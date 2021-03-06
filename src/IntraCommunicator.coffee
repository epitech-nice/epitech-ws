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

CsvParse = require('csv-parse');
HttpClient = require('./HttpClient.coffee');
moment = require('moment-timezone');
UrlCache  = require('./UrlCache.coffee');
When = require('when');

class IntraCommunicator

	constructor: (@login, @password) ->
		@sid = null;

	connect: () ->
		p = HttpClient.post("https://intra.epitech.eu", {login: @login, password: @password});
		p = p.then (data) =>
			if (data.res.statusCode != 302) then throw new Error("IntraCommunicator - Bad logins")
			for cookie in data.res.headers['set-cookie']
				cookie = cookie.split("; ")[0];
				cookie = cookie.split("=");
				if (cookie[0] == 'PHPSESSID')
					@sid = cookie[1];
		return p;


	intraToUTCTime: (dateString, timezoneFrom = 'Europe/Paris') ->
		offset = moment(new Date(dateString)).tz(timezoneFrom).zone() - new Date().getTimezoneOffset();
		return moment(new Date(dateString)).add(offset, 'm').toDate();

	getCalendar: (id) ->
		p = @_getJson("https://intra.epitech.eu/planning/#{id}/events?format=json");
		return p.then (json) =>
			events = []
			for event in json
				events.push({
					start: @intraToUTCTime(event.start),
					end: @intraToUTCTime(event.end),
					title: event.title
				});
			return events

	getCalendarInfos: (id) -> @_getJson("https://intra.epitech.eu/planning/#{id}?format=json");

	getCalendarPresent: (id) ->
		@getCalendarInfos(id).then (data) =>
			@_getCsv("https://intra.epitech.eu/planning/#{id}/exportattendance?start=#{data.start}&end=#{data.end}&promo[]=1&promo[]=2&promo[]=3").then (csv) =>
				res = {};
				for line in csv
					res[line.login] = {total_present: line['total des presences']};
				return res;

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

	getCityUsers: (city, year) -> @_getCityUserOffset(city, year, 0)

	getCityModules: (city, year) ->
		end = year;
		begin = end - 3;
		scholaryear = ""
		for year in [begin..end]
			scholaryear = "#{scholaryear}&scolaryear[]=#{year}"
		return @_getJson("https://intra.epitech.eu/course/filter?format=json&location=#{city}&#{scholaryear}").then (data) =>
			modules = []
			for module in data
				m = {};
				m.title = module.title;
				m.semester = module.semester;
				m.scholaryear = module.scolaryear;
				m.moduleCode = module.code;
				m.instanceCode = module.codeinstance;
				m.credits = module.credits;
				modules.push(m)
			return modules;


	getModuleRegistred: (year, moduleCode, instanceCode) ->
		@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}/registered?format=json").then (data) ->
			students = {}
			for student in data
				students[student.login] = {grade: student.grade, credits: student.credits}
			return students;

	getModulePresent: (year, moduleCode, instanceCode) ->
		@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}/present?format=json").then (data) ->
			students = data.present
			data = {}
			for s in students
				data[s.login] = {total_registered: s.total_registered, total_present: s.total_present, total_absent: s.total_absent};
			return data;


	getModuleActivities: (year, moduleCode, instanceCode) ->
		@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}?format=json").then (data) ->
			activities = [];
			for activity in data.activites
				ac = {name: activity.title, start: activity.start, end: activity.end, type: activity.type_code, activityCode: activity.codeacti, events:[]}
				for event in activity.events
					ac.events.push({eventCode:event.code, start: event.begin, end: event.end});
				activities.push(ac);
			return activities;

	getCityPlanning: (city, startDate, endDate) ->
		@_getJson("https://intra.epitech.eu/planning/load?format=json&start=#{startDate}&end=#{endDate}").then (data) =>
			planning = [];
			for ac in data
				if ac.id_calendar? then continue;
				if ac.instance_location != city then continue;
				ev = {
					module: {
						moduleCode: ac.codemodule,
						instanceCode: ac.codeinstance,
						semester: ac.semester,
						scholaryear: ac.scolaryear,
						title: ac.titlemodule
					},
					type: ac.type_code,
					start: @intraToUTCTime(ac.start),
					end: @intraToUTCTime(ac.end),
					activityCode: ac.codeacti,
					eventCode:ac.codeevent,
					title: ac.acti_title,
					place: if (ac.room?) then (ac.room.code) else null;
				}
				planning.push(ev);
			return planning;

	getUser: (login) ->
		@_getJson("https://intra.epitech.eu/user/#{login}/?format=json", moment().add(1, 'd').toDate()).then (data) =>
			user = {};
			user.login = data.login;
			if (user.lastname and user.firstname)
				user.lastname = data.lastname;
				user.firstname = data.firstname;
			else
				[user.firstname, user.lastname] = data.title.split(" ", 2);
				user.picture = data.picture;
				user.promo = if (data.promo?) then (data.promo) else ("ADM");
				user.semester = if (data.semester?) then (data.semester) else (0);
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
		@_getJson("https://intra.epitech.eu/user/#{login}/notes?format=json", moment().add(1, 'd').toDate()).then (data) =>
			modules = [];
			for module in data.modules
				m = {};
				m.scholaryear = module.scolaryear;
				m.title = module.title;
				m.grade = module.grade;
				m.credits = module.credits;
				m.semester = module.semester;
				m.moduleCode = module.codemodule;
				m.instanceCode = module.codeinstance;
				modules.push(m);
			return modules;



	getEventRegistered: (year, moduleCode, instanceCode, activityCode, eventCode) ->
		@_getJson("https://intra.epitech.eu/module/#{year}/#{moduleCode}/#{instanceCode}/#{activityCode}/#{eventCode}/registered?format=json").then (data) =>
			users = {};
			for line in data
				users[line.login] = {present: if (line.present == "present") then true else false};
			return users;

	_getCityUserOffset: (city, year, offset) ->
		users = []
		ttl = moment().add(1, 'd').toDate();
		return @_getJson("https://intra.epitech.eu/user/filter/user?format=json&year=#{year}&active=true&location=#{city}&offset=#{offset}", ttl).then (data) =>
				for user in data.items
					users.push(user.login);
				if (data.items.length + offset < data.total)
					return @_getCityUserOffset(city, year, data.items.length + offset).then (users2) ->
						users = users.concat(users2)
				return users;

	_getCompleteNsLog: (login) ->
		@_getJson("https://intra.epitech.eu/user/#{login}/netsoul?format=json", moment().add(1, 'd').startOf('day').add(5, 'h').toDate()).then (json) ->
			report = {};
			for rawDay in json
				day = {school:rawDay[1], idleSchool:rawDay[2], out:rawDay[3], idleOut:rawDay[4], avg:rawDay[5]};
				date = moment.unix(rawDay[0]).tz("Europe/Paris").format("YYYY-MM-DD");
				report[date] = day;
			return report;

	_get: (url, ttl) ->
		ttl = if (ttl?) then ttl else moment().add(15, 'm').toDate();
		return UrlCache.findOrInsert url, ttl, () =>
			return	HttpClient.get(url, {headers:{Cookie:"PHPSESSID=#{@sid};language=fr"}}).then (res) =>
				if (res.res.statusCode == 403)
					return @connect().then () => @_get(url)
				return res.data;

	_getJson: (url, ttl) ->
		p = @_get(url, ttl)
		return p.then (jsonStr) ->
			jsonStr = jsonStr.replace("// Epitech JSON webservice ...", "");
			try
				data = JSON.parse(jsonStr);
			catch e
				console.log(e);
				console.log(jsonStr);
			if (data.error?) then throw "Intra: #{data.error}"
			return data;

	_getCsv: (url, ttl) ->
		p = @_get(url, ttl)
		return p.then (csvStr) ->
			defer = When.defer();
			csv = CsvParse csvStr, { columns:true, delimiter: ';'}, (err, data) ->
				if err?
					defer.reject(err)
					return
				defer.resolve(data);
			return defer.promise;

module.exports = IntraCommunicator;
