##
# The MIT License (MIT)
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

Aer = require('./Aer.coffee');
Cache = require('./Cache.coffee');
Calendar = require('./Calendar.coffee');
Config = require('./Config.coffee');
Database = require('./Database.coffee');
express = require('express');
fn = require('when/function');
HttpJsonResponse = require('./HttpJsonResponse.coffee');
IntraCommunicator = require('./IntraCommunicator.coffee');
Logger = require('./Logger.coffee');
moment = require('moment-timezone');
NsWatch = require('./NsWatch.coffee');
Utils = require('./Utils.coffee');
When = require('when');

class Application
	constructor: () ->
		@express = express();
		@server = null
		@database = new Database(Config.get('database'));
		@intraCommunicator = new IntraCommunicator(Config.get('login'), Config.get('password'))
		@nsWatch = {};
		for city in Config.get("cities")
			@nsWatch[city] = new NsWatch(Config.get('ns-server'), Config.get('ns-port'), Config.get('ns-login'), Config.get('ns-password'));
		@initRoutes()
		@initSignals();
		Cache.setDb(@database);

	start: () ->
		Logger.info("Start Application")
		p = @database.start().then () =>
			Logger.info "Connection to database SUCCESS"
			return @intraCommunicator.connect().then () =>
				Logger.info "Connection to intranet SUCCESS"
				promises = for city in Config.get("cities")
					@initNsWatch(city, Config.get('scolar-year'));
				return When.all(promises);

		p.then () =>
			Logger.info("Listening on #{Config.get('server.port')}");
			@server = @express.listen(Config.get('server.port'))
		p.otherwise (err) =>
			Logger.error("Application: #{err}");
			if (err.stack?) then Logger.error(err.stack);
			process.exit(1);

	initNsWatch: (city, scholarYear) ->
		return @intraCommunicator.getCityUsers(city, scholarYear).then (users) =>
			logins = [];
			logins.push(user.login) for user in users;
			return @nsWatch[city].start(logins);

	stop: () ->
		@database.stop();
		Logger.info("Stopping database")
		@server.close();
		Logger.info("Stopping http server")
		for city, nsWatch of @nsWatch
			nsWatch.stop();
		Logger.info("Stopping netsoul")

	handleRequest: (req, res, handler) =>
		p = fn.call(handler, req, res)
		if (p == null) then return res.json(HttpJsonResponse.error(404));
		p.then (data) ->
			if (typeof data != "object") then res.end(data) else res.json(HttpJsonResponse.success(data))

		p.otherwise (error) ->
			code = if (error.code?) then error.code else 500;
			msg = if (error.msg?) then error.msg else "" + error;
			if (error.stack) then Logger.error(error.stack);
			res.json(HttpJsonResponse.error(code, msg));

	simulateGet: (url) =>
		for route in @express._router.stack
			if (!route.route?) then continue
			if ((res = route.regexp.exec(url)))
				params = {}
				i = 1;
				for key in route.keys
					params[key.name] = res[i++]
				res = When.defer();
				res.json = (data) -> @resolve({url: url, data: data});
				route.route.stack[0].handle({originalUrl: url, params: params, query: {}}, res);
				return res.promise;
		return HttpJsonResponse.error(404);

	onChainedRequest: (req, res, data) =>
		urls = req.query.urls;
		if (!urls?) then throw "Bad params"
		if (typeof urls == "string") then urls = [urls];
		p = for url in urls
			@simulateGet(url);
		return When.all(p)

	onCityIcsPlanningRequest: (req, res) =>
		res.type("text/calendar");
		city = @checkCityFromRequest(req);
		startDate = moment().subtract('month', 1).format("YYYY-MM-DD");
		endDate = moment().add(4, 'month').format("YYYY-MM-DD");
		calendar = new Calendar();
		Cache.findOrInsert req.originalUrl, moment().add(4, 'h').toDate(), () =>
			@intraCommunicator.getCityPlanning(city, startDate, endDate).then (events) ->
				for event in events
					calendar.addEvent(event.title, event.start, event.end, null).setPlace(event.place)
				return calendar.toVCal();


	onCityPlanningRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		start = @checkParamDate(req.query, 'start')
		end = @checkParamDate(req.query, 'end')
		Cache.findOrInsert req.originalUrl, moment().add(4, 'h').toDate(), () =>
			return @intraCommunicator.getCityPlanning(city, start, end);

	onUserNsLogRequest: (req, res) =>
		login = req.params.login;
		start = @checkParamDate(req.query, 'start')
		end = @checkParamDate(req.query, 'end')
		Cache.findOrInsert req.originalUrl, moment().add(1, 'day').startOf('day').add(5, 'h').toDate(), () =>
			return @intraCommunicator.getNsLog(login, start, end);

	onCityModulesRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		filters = null
		if (req.query.year?)
			filters = {scolaryear: parseInt(@checkParam(req.query, 'year'))}
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getCityModules(city, Config.get('scolar-year')).then (ms) ->
				modules = []
				for m in ms
					if (Utils.match(m, filters)) then modules.push(m)
				return modules

	onModuleRegisteredRequest: (req, res) =>
		year = @checkParam(req.params, 'year')
		moduleCode = @checkParam(req.params, 'moduleCode')
		instanceCode = @checkParam(req.params, 'instanceCode')
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getModuleRegistred(year, moduleCode, instanceCode)

	onModulePresentRequest: (req, res) =>
		year = @checkParam(req.params, 'year')
		moduleCode = @checkParam(req.params, 'moduleCode')
		instanceCode = @checkParam(req.params, 'instanceCode')
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getModulePresent(year, moduleCode, instanceCode)

	onModuleActivitiesRequest: (req, res) =>
		year = @checkParam(req.params, 'year')
		moduleCode = @checkParam(req.params, 'moduleCode')
		instanceCode = @checkParam(req.params, 'instanceCode')
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getModuleActivities(year, moduleCode, instanceCode)

	onCityUsersRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getCityUsers(city, Config.get('scolar-year'));

	onCityAerDutyRequest: (req, res) =>
		city = @checkCityFromRequest(req);
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			Aer.getDuty();

	onUserRequest: (req, res) =>
		login = @checkParam(req.params, 'login');
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getUser(login);

	onCityNetsoulRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		@nsWatch[city].getReport();

	onCityNsLogRequest: (req, res) =>
		city = @checkCityFromRequest(req);
		start = @checkParamDate(req.query, 'start')
		end = @checkParamDate(req.query, 'end')
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').startOf('day').add(5, 'h').toDate(), () =>
			res = {}
			promises = for login, log of @nsWatch[city].getReport()
				do (login) =>
					@intraCommunicator.getNsReport(login, start, end).then (r) =>
						res[login] = r;
			return When.all(promises).then () ->
				res

	onUserModulesRequest: (req, res) =>
		login = @checkParam(req.params, 'login')
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getUserModules(login);

	onCalendarIcsRequest: (req, res) =>
		id = @checkParam(req.params, 'id');
		res.type("text/calendar");
		calendar = new Calendar();
		Cache.findOrInsert req.originalUrl, moment().add(4, 'h').toDate(), () =>
			@intraCommunicator.getCalendar(id).then (events) ->
				for event in events
					calendar.addEvent(event.title, event.start, event.end);
				return calendar.toVCal();

	onCalendarPresentRequest: (req, res) =>
		id = @checkParam(req.params, 'id');
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getCalendarPresent(id);

	onEventRegisteredRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		activityCode = req.params.activityCode;
		eventCode = req.params.eventCode;
		Cache.findOrInsert req.originalUrl, moment().add(4, 'h').toDate(), () =>
			@intraCommunicator.getEventRegistered(year, moduleCode, instanceCode, activityCode, eventCode);

	checkParam: (tab, name) ->
		if (!tab[name]?) then throw "Missing #{name} parameter"
		return tab[name]

	checkParamDate: (tab, name) ->
		if (! tab[name]?) then throw "Missing #{name} parameter"
		if (!moment(tab[name]).isValid()) then throw "#{name} is not a valid date"
		return tab[name]

	checkCityFromRequest: (req) ->
		city = "#{req.params.country}/#{req.params.city}"
		if (city not in Config.get('cities')) then throw "Bad city"
		return city

	initRoutes: () ->
		@express.use (req, res, next) ->
			res.header('Access-Control-Allow-Origin', '*');
			res.header("Access-Control-Allow-Headers", "X-Requested-With");
			next();


		handleRequest = (handler) => (req, res) => @handleRequest(req, res, handler);
		@express.get('/chained', handleRequest(@onChainedRequest))
		@express.get('/calendar/:id.ics', handleRequest(@onCalendarIcsRequest))
		@express.get('/calendar/:id/present', handleRequest(@onCalendarPresentRequest))
		@express.get('/user/:login', handleRequest(@onUserRequest))
		@express.get('/user/:login/nslog', handleRequest(@onUserNsLogRequest))
		@express.get('/user/:login/modules', handleRequest(@onUserModulesRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/registered', handleRequest(@onModuleRegisteredRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/present', handleRequest(@onModulePresentRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/activities', handleRequest(@onModuleActivitiesRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/:activityCode/:eventCode/registered', handleRequest(@onEventRegisteredRequest))
		@express.get('/:country/:city/planning.ics', handleRequest(@onCityIcsPlanningRequest))
		@express.get('/:country/:city/planning', handleRequest(@onCityPlanningRequest))
		@express.get('/:country/:city/modules', handleRequest(@onCityModulesRequest))
		@express.get('/:country/:city/users', handleRequest(@onCityUsersRequest))
		@express.get('/:country/:city/aer/duty', handleRequest(@onCityAerDutyRequest))
		@express.get('/:country/:city/netsoul', handleRequest(@onCityNetsoulRequest))
		@express.get('/:country/:city/nslog', handleRequest(@onCityNsLogRequest))

	initSignals: () ->
		process.on 'SIGINT', () =>
			Logger.info('Receive SIGINT');
			@stop();

module.exports = Application;
