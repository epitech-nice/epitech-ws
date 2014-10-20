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
Config = require('./Config.coffee');
Database = require('./Database.coffee');
express = require('express');
fn = require('when/function');
HttpJsonResponse = require('./HttpJsonResponse.coffee');
IntraCommunicator = require('./IntraCommunicator.coffee');
Logger = require('./Logger.coffee');
moment = require('moment-timezone');
NsWatch = require('./NsWatch.coffee');
When = require('when');

class Application
	constructor: () ->
		@express = express();
		@server = null
		@database = new Database('test.db');
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
		for route in @express.routes.get
			if ((res = route.regexp.exec(url)))
				params = {}
				i = 1;
				for key in route.keys
					params[key.name] = res[i++]
				res = When.defer();
				res.json = (data) -> @resolve({url: url, data: data});
				route.callbacks[0]({originalUrl: url, params: params, query: {}}, res);
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
		Cache.findOrInsert req.originalUrl, moment().add(4, 'h').toDate(), () =>
			@intraCommunicator.getCityPlanning(city).then (cal) ->
				return cal.toVCal();

	onUserNsLogRequest: (req, res) =>
		login = req.params.login;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'day').startOf('day').add(5, 'h').toDate(), () =>
			params = req.query;
			return @intraCommunicator.getNsLog(login, params.start, params.end);

	onModuleAllRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		Cache.findOrInsert req.originalUrl, moment().add(7, 'd').toDate(), () =>
			@intraCommunicator.getCityModules(city, Config.get('scolar-year'));

	onModuleRegisteredRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getModuleRegistred(year, moduleCode, instanceCode)

	onModulePresentRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getModulePresent(year, moduleCode, instanceCode)

	onModuleActivitiesRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getModuleActivities(year, moduleCode, instanceCode)

	onUserAllRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		Cache.findOrInsert req.originalUrl, moment().add(7, 'd').toDate(), () =>
			@intraCommunicator.getCityUsers(city, Config.get('scolar-year'));

	onAerDutyRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add(6, 'h').toDate(), () =>
			Aer.getDuty();

	onUserRequest: (req, res) =>
		login = req.params.login;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getUser(login);

	onNetsoulRequest: (req, res) =>
		city = @checkCityFromRequest(req)
		@nsWatch[city].getReport();

	onNetsoulReportRequest: (req, res) =>
		city = @checkCityFromRequest(req);
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').startOf('day').add(5, 'h').toDate(), () =>
			params = req.query;
			res = {}
			promises = for login, log of @nsWatch[city].getReport()
				do (login) =>
					@intraCommunicator.getNsReport(login, params.start, params.end).then (r) =>
						res[login] = r;
			return When.all(promises).then () ->
				res

	onUserModulesRequest: (req, res) =>
		login = req.params.login
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getUserModules(login);

	onYearModuleRequest: (req, res) =>
		city = @checkCityFromRequest(req);
		year = req.params.year;
		Cache.findOrInsert req.originalUrl, moment().add(7, 'd').toDate(), () =>
			@intraCommunicator.getCityModules(city, Config.get('scolar-year'), {scolaryear: parseInt(year)});

	onCalendarIcsRequest: (req, res) =>
		if (!req.params.id?) then throw "Bad Params";
		id = req.params.id;
		res.type("text/calendar");
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getCalendar(id).then (cal) ->
				return cal.toVCal();

	onCalendarPresentRequest: (req, res) =>
		if (!req.params.id?) then throw "Bad Params";
		id = req.params.id;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').toDate(), () =>
			@intraCommunicator.getCalendarPresent(id);

	onPlanningRequest: (req, res) =>
		#TODO Test for all city
		Cache.findOrInsert req.originalUrl, moment().add(1, 'd').startOf('day').toDate(), () =>
			params = req.query;
			if (!params.start? || ! params.end?) then throw "Bad Params";
			return @intraCommunicator.getPlanning(params.start, params.end);

	onEventRegisteredRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		activityCode = req.params.activityCode;
		eventCode = req.params.eventCode;
		Cache.findOrInsert req.originalUrl, moment().add(1, 'h').toDate(), () =>
			@intraCommunicator.getEventRegistered(year, moduleCode, instanceCode, activityCode, eventCode);


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
		@express.get('/:country/:city/planning.ics', handleRequest(@onCityIcsPlanningRequest))
		@express.get('/planning', handleRequest(@onPlanningRequest))
		@express.get('/:country/:city/module/all', handleRequest(@onModuleAllRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/registered', handleRequest(@onModuleRegisteredRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/present', handleRequest(@onModulePresentRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/activities', handleRequest(@onModuleActivitiesRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/:activityCode/:eventCode/registered', handleRequest(@onEventRegisteredRequest))
		@express.get('/module/:year/all', handleRequest(@onYearModuleRequest))
		@express.get('/:country/:city/user/all', handleRequest(@onUserAllRequest))
		@express.get('/user/:login', handleRequest(@onUserRequest))
		@express.get('/user/:login/nslog', handleRequest(@onUserNsLogRequest))
		@express.get('/user/:login/modules', handleRequest(@onUserModulesRequest))
		@express.get('/aer/duty', handleRequest(@onAerDutyRequest))
		@express.get('/:country/:city/netsoul', handleRequest(@onNetsoulRequest))
		@express.get('/:country/:city/netsoul/report', handleRequest(@onNetsoulReportRequest))
		@express.get('/chained', handleRequest(@onChainedRequest))
		@express.get('/calendar/:id.ics', handleRequest(@onCalendarIcsRequest))
		@express.get('/calendar/:id/present', handleRequest(@onCalendarPresentRequest))

	initSignals: () ->
		process.on 'SIGINT', () =>
			Logger.info('Receive SIGINT');
			@stop();

module.exports = Application;
