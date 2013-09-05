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
IntraCommunicator = require('./IntraCommunicator.coffee');
Logger = require('./Logger.coffee');
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
		Cache.setDb(@database);

	run: () ->
		Logger.info("Start Application")
		p = @database.run();
		p = When.join(p, @intraCommunicator.connect());
		p.then () => @server.run()
		p.otherwise (err) =>
			Logger.error(err)
			process.exit(1);

	onRequest: (req, res) =>
		p = @routeManager.exec(req, res)
		if (p == null) then return res.error(404);
		p.then (data) -> res.success(data)
		p.otherwise (error) ->
			code = if (error.code?) then error.code else 500;
			msg = if (error.msg?) then error.msg else "" + error;
			if (error.stack) then Logger.error(error.stack);
			res.error(code, msg)


	onPedagoPlanningRequest: (req, res) =>
		return @intraCommunicator.getCalandar(516).then (cal) ->
			res.setMime("text/calendar");
			return cal.toVCal();

	onNsLogRequest: (req, res, data) =>
		params = req.getQuery();
		return @intraCommunicator.getNsLog(data.login, params.start, params.end);

	onAerDutyRequest: (req, res) -> Aer.getDuty();


	initRoutes: () ->
		@routeManager.addRoute('/planning/pedago.ics', @onPedagoPlanningRequest)
		@routeManager.addRoute('/user/$login/nslog', @onNsLogRequest)
		@routeManager.addRoute('/aer/duty', @onAerDutyRequest)

module.exports = Application;