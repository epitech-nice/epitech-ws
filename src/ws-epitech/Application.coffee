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

Calendar = require('./Calendar.coffee');
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
		@intraCommunicator = new IntraCommunicator();
		@initRoutes()

	run: () ->
		Logger.info("Start Application")
		p = @database.run();
		p = When.join(p, @intraCommunicator.connect());
		p.then () => @server.run()
		p.otherwise (err) =>
			console.log(err)
			process.exit(1);

	onRequest: (req, res) =>
		p = @routeManager.exec(req, res)
		if (p == null) then return res.error(404);
		p.then (data) -> res.success(data)
		p.otherwise (error) ->
			code = if (error.code?) then error.code else 500;
			msg = if (error.msg?) then error.msg else "" + error;
			res.error(code, msg)

	onPedagoPlanningRequest: (req, res) =>
		p = @intraCommunicator.getCalandarEvents(516);
		p = p.then (json) ->
			cal = new Calendar();
			for activity in json.activities
				cal.addEvent(activity.title, new Date(activity.start), new Date(activity.end));
			res.setMime("text/calendar");
			return cal.toVCal();
		return p

	initRoutes: () ->
		@routeManager.addRoute('/planning/pedago.ics', @onPedagoPlanningRequest)

module.exports = Application;