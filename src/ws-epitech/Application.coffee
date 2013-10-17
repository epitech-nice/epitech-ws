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

Aer = require('./Aer.coffee');
Cache = require('./Cache.coffee');
Config = require('./Config.coffee');
Database = require('./Database.coffee');
HttpServer = require('./HttpServer.coffee');
HttpRequest = require('./HttpRequest.coffee');
HttpResponse = require('./HttpResponse.coffee');
HttpJsonResponse = require('./HttpJsonResponse.coffee');
IntraCommunicator = require('./IntraCommunicator.coffee');
Logger = require('./Logger.coffee');
NsWatch = require('./NsWatch.coffee');
RouteManager = require('./RouteManager.coffee');
When = require('when');

class Application
	constructor: () ->
		@server = new HttpServer(Config.get('server.port'))
		@database = new Database();
		@server.on('get', @onRequest)
		@routeManager = new RouteManager()
		@intraCommunicator = new IntraCommunicator(@database);
		@initRoutes()
		@nsWatch = new NsWatch();
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
		p.then () => @server.run()
		p.otherwise (err) =>
			Logger.error("Application: #{err}");
			process.exit(1);


	onRequest: (req, res) =>
		p = @routeManager.exec(req, res)
		if (p == null) then return res.endJSON(HttpJsonResponse.error(404));
		p.then (data) ->
			if (typeof data != "object") then res.end(data) else res.endJSON(HttpJsonResponse.success(data))

		p.otherwise (error) ->
			code = if (error.code?) then error.code else 500;
			msg = if (error.msg?) then error.msg else "" + error;
			if (error.stack) then Logger.error(error.stack);
			res.endJSON(HttpJsonResponse.error(code, msg));

	onChainedRequest: (req, res, data) =>
		urls = req.getQuery().urls;
		if (!urls?) then throw "Bad params"
		if (typeof urls == "string") then urls = [urls];
		p = for url in urls
			f = (req, res) =>
				promise = @routeManager.exec(req, res);
				d = When.defer();
				if (promise == null)
					d.resolve({url: req.getUrl(), data: HttpJsonResponse.error(404)});
				else
					promise.then (data) -> d.resolve({url: req.getUrl(), data: HttpJsonResponse.success(data)});
					promise.otherwise (error) ->
						code = if (error.code?) then error.code else 500;
						msg = if (error.msg?) then error.msg else "" + error;
						if (error.stack) then Logger.error(error.stack);
						d.resolve({url: req.getUrl(), data: HttpJsonResponse.error(code, msg)});
				return d.promise;
			f(new HttpRequest().setUrl(url), new HttpResponse())
		return When.all(p)

	onPedagoPlanningRequest: (req, res) =>
		return @intraCommunicator.getCalandar(516).then (cal) ->
			res.setMime("text/calendar");
			return cal.toVCal();

	onUserNsLogRequest: (req, res, data) =>
		params = req.getQuery();
		return @intraCommunicator.getNsLog(data.login, params.start, params.end);

	onModuleAllRequest: (req, res) => @intraCommunicator.getCityModules("FR/NCE");
	onModuleRegisteredRequest: (req, res, data) => @intraCommunicator.getModuleRegistred(data.year, data.moduleCode, data.instanceCode)
	onModulePresentRequest: (req, res, data) => @intraCommunicator.getModulePresent(data.year, data.moduleCode, data.instanceCode)
	onModuleProjectsRequest: (req, res, data) => @intraCommunicator.getModuleProject(data.year, data.moduleCode, data.instanceCode)
	onUserAllRequest: (req, res) => @intraCommunicator.getCityUsers("FR/NCE");
	onAerDutyRequest: (req, res) => Aer.getDuty();
	onUserRequest: (req, res, data) => @intraCommunicator.getUser(data.login);
	onNetsoulRequest: (req, res) => @nsWatch.getReport();
	onNetsoulReportRequest: (req, res, data) =>
		params = req.getQuery();
		res = {}
		promises = for login, log of @nsWatch.getReport()
			((login) =>
				@intraCommunicator.getNsReport(login, params.start, params.end).then (r) =>
					res[login] = r;
			)(login)
		return When.all(promises).then () ->
			res

	onUserModulesRequest: (req, res, data) => @intraCommunicator.getUserModules(data.login);
	onYearModuleRequest: (req, res, data) => @intraCommunicator.getCityModules("FR/NCE", {scolaryear: parseInt(data.year)});

	onSusiePresentRequest: (req, res) => @intraCommunicator.getCalendarPresent(Config.get('susies-calendar-id'));

	initRoutes: () ->
		@routeManager.addRoute('/planning/pedago.ics', @onPedagoPlanningRequest)
		@routeManager.addRoute('/module/all', @onModuleAllRequest)
		@routeManager.addRoute('/module/$year/$moduleCode/$instanceCode/registered', @onModuleRegisteredRequest)
		@routeManager.addRoute('/module/$year/$moduleCode/$instanceCode/present', @onModulePresentRequest)
		@routeManager.addRoute('/module/$year/$moduleCode/$instanceCode/project', @onModuleProjectsRequest)
		@routeManager.addRoute('/module/$year/all', @onYearModuleRequest)
		@routeManager.addRoute('/user/all', @onUserAllRequest)
		@routeManager.addRoute('/user/$login', @onUserRequest)
		@routeManager.addRoute('/user/$login/nslog', @onUserNsLogRequest)
		@routeManager.addRoute('/user/$login/modules', @onUserModulesRequest)
		@routeManager.addRoute('/aer/duty', @onAerDutyRequest)
		@routeManager.addRoute('/netsoul', @onNetsoulRequest)
		@routeManager.addRoute('/netsoul/report', @onNetsoulReportRequest)
		@routeManager.addRoute('/chained', @onChainedRequest)
		@routeManager.addRoute('/susie/present', @onSusiePresentRequest)

module.exports = Application;