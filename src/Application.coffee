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
		@database = new Database();
		@intraCommunicator = new IntraCommunicator(@database);
		@nsWatch = new NsWatch();
		@initRoutes()
		Cache.setDb(@database);

	run: () ->
		Logger.info("Start Application")
		p = @database.run().then () =>
			return @intraCommunicator.connect().then () =>
				@intraCommunicator.getCityUsers("FR/NCE").then (users) =>
					logins = [];
					logins.push(user.login) for user in users;
					if (Config.get('ns-watch')?) then logins = logins.concat(Config.get('ns-watch'));
					@nsWatch.run(logins);
		console.log("Listening on #{Config.get('server.port')}");
		p.then () => @express.listen(Config.get('server.port'))
		p.otherwise (err) =>
			Logger.error("Application: #{err}");
			process.exit(1);


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
				route.callbacks[0]({originalUrl: url, params: params}, res);
				return res.promise;
		return HttpJsonResponse.error(404);

	onChainedRequest: (req, res, data) =>
		urls = req.query.urls;
		if (!urls?) then throw "Bad params"
		if (typeof urls == "string") then urls = [urls];
		p = for url in urls
			@simulateGet(url);
		return When.all(p)

	onPedagoPlanningRequest: (req, res) =>
		res.type("text/calendar");
		Cache.findOrInsert req.originalUrl, moment().add('h', 1).toDate(), () =>
			@intraCommunicator.getCalandar(516).then (cal) ->
				return cal.toVCal();

	onSusiePlanningRequest: (req, res) =>
		res.type("text/calendar");
		Cache.findOrInsert req.originalUrl, moment().add('h', 1).toDate(), () =>
			@intraCommunicator.getCalandar(627).then (cal) ->
				return cal.toVCal();

	onAerPlanningRequest: (req, res) =>
		res.type("text/calendar");
		Cache.findOrInsert req.originalUrl, moment().add('h', 1).toDate(), () =>
			@intraCommunicator.getCalandar(1236).then (cal) ->
				return cal.toVCal();

	onCityIcsPlanningRequest: (req, res) =>
		res.type("text/calendar");
		city = req.params.city;
		Cache.findOrInsert req.originalUrl, moment().add('h', 4).toDate(), () =>
			@intraCommunicator.getCityPlanning(city).then (cal) ->
				return cal.toVCal();

	onUserNsLogRequest: (req, res) =>
		login = req.params.login;
		Cache.findOrInsert req.originalUrl, moment().add('day', 1).startOf('day').add('h', 5).toDate(), () =>
			params = req.query;
			return @intraCommunicator.getNsLog(login, params.start, params.end);

	onModuleAllRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add('d', 7).toDate(), () =>
			@intraCommunicator.getCityModules("FR/NCE");

	onModuleRegisteredRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).toDate(), () =>
			@intraCommunicator.getModuleRegistred(year, moduleCode, instanceCode)

	onModulePresentRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).toDate(), () =>
			@intraCommunicator.getModulePresent(year, moduleCode, instanceCode)

	onModuleActivitiesRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).toDate(), () =>
			@intraCommunicator.getModuleActivities(year, moduleCode, instanceCode)

	onUserAllRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add('d', 7).toDate(), () =>
			@intraCommunicator.getCityUsers("FR/NCE");

	onAerDutyRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add('h', 6).toDate(), () =>
			Aer.getDuty();

	onUserRequest: (req, res) =>
		login = req.params.login;
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).toDate(), () =>
			@intraCommunicator.getUser(login);

	onNetsoulRequest: (req, res) =>
		@nsWatch.getReport();

	onNetsoulReportRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).startOf('day').add('h', 5).toDate(), () =>
			params = req.query;
			res = {}
			promises = for login, log of @nsWatch.getReport()
				((login) =>
					@intraCommunicator.getNsReport(login, params.start, params.end).then (r) =>
						res[login] = r;
				)(login)
			return When.all(promises).then () ->
				res

	onUserModulesRequest: (req, res) =>
		login = req.params.login
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).toDate(), () =>
			@intraCommunicator.getUserModules(login);

	onYearModuleRequest: (req, res) =>
		year = req.params.year;
		Cache.findOrInsert req.originalUrl, moment().add('d', 7).toDate(), () =>
			@intraCommunicator.getCityModules("FR/NCE", {scolaryear: parseInt(year)});

	onSusiePresentRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).toDate(), () =>
			@intraCommunicator.getCalendarPresent(Config.get('susies-calendar-id'));

	onPlanningRequest: (req, res) =>
		Cache.findOrInsert req.originalUrl, moment().add('d', 1).startOf('day').toDate(), () =>
			params = req.query;
			if (!params.start? || ! params.end?) then throw "Bad Params";
			return @intraCommunicator.getPlanning(params.start, params.end);

	onEventRegisteredRequest: (req, res) =>
		year = req.params.year;
		moduleCode = req.params.moduleCode;
		instanceCode = req.params.instanceCode;
		activityCode = req.params.activityCode;
		eventCode = req.params.eventCode;
		Cache.findOrInsert req.originalUrl, moment().add('h', 1).toDate(), () =>
			@intraCommunicator.getEventRegistered(year, moduleCode, instanceCode, activityCode, eventCode);

	initRoutes: () ->
		@express.use (req, res, next) ->
			res.header('Access-Control-Allow-Origin', '*');
			res.header("Access-Control-Allow-Headers", "X-Requested-With");
			next();


		handleRequest = (handler) => (req, res) => @handleRequest(req, res, handler);
		@express.get('/planning/aer.ics', handleRequest(@onAerPlanningRequest))
		@express.get('/planning/pedago.ics', handleRequest(@onPedagoPlanningRequest))
		@express.get('/planning/susie.ics', handleRequest(@onSusiePlanningRequest))
		@express.get('/planning/:city.ics', handleRequest(@onCityIcsPlanningRequest))
		@express.get('/planning', handleRequest(@onPlanningRequest))
		@express.get('/module/all', handleRequest(@onModuleAllRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/registered', handleRequest(@onModuleRegisteredRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/present', handleRequest(@onModulePresentRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/activities', handleRequest(@onModuleActivitiesRequest))
		@express.get('/module/:year/:moduleCode/:instanceCode/:activityCode/:eventCode/registered', handleRequest(@onEventRegisteredRequest))
		@express.get('/module/:year/all', handleRequest(@onYearModuleRequest))
		@express.get('/user/all', handleRequest(@onUserAllRequest))
		@express.get('/user/:login', handleRequest(@onUserRequest))
		@express.get('/user/:login/nslog', handleRequest(@onUserNsLogRequest))
		@express.get('/user/:login/modules', handleRequest(@onUserModulesRequest))
		@express.get('/aer/duty', handleRequest(@onAerDutyRequest))
		@express.get('/netsoul', handleRequest(@onNetsoulRequest))
		@express.get('/netsoul/report', handleRequest(@onNetsoulReportRequest))
		@express.get('/chained', handleRequest(@onChainedRequest))
		@express.get('/susie/present', handleRequest(@onSusiePresentRequest))

module.exports = Application;