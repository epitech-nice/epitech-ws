##
# Copyright 2012 Jerome Quere < contact@jeromequere.com >.
#
# This file is part of ws-epitech.
#
# ws-epitech is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ws-epitech is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ws-epitech.If not, see <http://www.gnu.org/licenses/>.
##

EventEmitter = require('events').EventEmitter;
Config = require('./Config.coffee');
crypto = require('crypto');
Logger = require('./Logger.coffee');
net = require('net');
When = require('when');


class Communicator extends EventEmitter

	constructor: (@serverName, @serverPort) ->
		@client = null;
		@connected = false;
		@buffer = "";

	run: () ->
		@connected = true;
		@client = net.connect(@serverPort, @serverName, @onConnect);
		@client.setTimeout(1000 * 60 * 60);
		@client.setEncoding('ascii');
		@client.on('data', @onData);
		@client.on('error', @onError);
		@client.on('close', @onClose);
		@client.on('timeout', @onTimeut);

	onConnect: () =>
		@emit('connect')

	send:(msg) ->
		Logger.debug("Netsoul# > #{msg}");
		@client.write("#{msg}\r\n", "ascii");


	onData: (data) =>
		@buffer = "#{@buffer}#{data}";
		while ((i = @buffer.indexOf("\n")) != -1)
			Logger.debug("Netsoul# < #{@buffer.slice(0, i)}");
			@emit("cmd", @buffer.slice(0, i));
			@buffer = @buffer.slice(i + 1);

	onTimeout: () =>
		@onError();

	onError: () =>
		@client.destroy();
		@_onDisconnect()

	onClose: () =>
		@client.destroy();
		@_onDisconnect()

	_onDisconnect: () =>
		if (@connected)
			@connected = false;
			@emit("disconnect");


class NsClientLogger
	constructor: (logins) ->
		@logins = {}
		for login in logins
			@logins[login] = {sockets:[]};

	log: (user) ->
		sockets = @logins[user.login].sockets;
		infos = {socket:user.socket, isAtEpitech: user.isAtEpitech, isActif:user.status == "actif"};
		i = 0;
		while ( i < sockets.length )
			if (sockets[i].socket == user.socket)
				if (user.connected)
					sockets[i] = infos
				else
					sockets.splice(i, 1);
				return;
			i++;
		sockets.push(infos)

	getReport: () ->
		return @logins;

	getLogins: () ->
		logins = [];
		for login, status of @logins
			logins.push(login)
		return logins;


class NsClient

	constructor: (logins) ->
		@communicator = new Communicator(Config.get('ns-server'), Config.get('ns-port'));
		@communicator.on('cmd', @_onCmd);
		@communicator.on('disconnect', @_onDisconnect);
		@logger = new NsClientLogger(logins);
		@callback = null;
		@runDefer = When.defer();

	run: () ->
		@communicator.run();
		return @runDefer.promise;

	getReport: () -> @logger.getReport();

	_onCmd: (cmd) =>
		handlers = [];
		handlers.push({regex:/^ping/, method:@_onPing});
		handlers.push({regex:/^salut/, method:@_onSalut});
		handlers.push({regex:/^rep /, method:@_onMessage});
		handlers.push({regex:/^[0-9]+ [a-z_0-9-]+ [^ ]+ [0-9]+ [0-9]+/, method:@_onUserInfo});
		handlers.push({regex:/^user_cmd [0-9]+:user:/, method:@_onUserUpdate});
		for handler in handlers
			if (handler.regex.exec(cmd))
				res = handler.method(cmd);
				break


	_send: (cmd) ->
		defer = When.defer();
		@callback = (success) ->
			if (success == true)
				defer.resolve(true);
			else
				defer.reject("Error Netsoul");
		@communicator.send(cmd);
		return defer.promise;


	_login: () ->
		@_send("auth_ag ext_user none none").then () =>
			hash = crypto.createHash('md5')
			hash.update("#{@md5Hash}-#{@clientIp}/#{@clientPort}#{Config.get('ns-password')}");
			@_send("ext_user_log #{Config.get('ns-login')} #{hash.digest('hex')} none none").then () =>
				logins = @logger.getLogins();
				@runDefer.resolve(true);
				@_send("state server:#{new Date().getTime();}")
				@_send("user_cmd watch_log_user {#{logins.join(',')}}")
				@_send("list_users {#{logins.join(',')}}")


	_onSalut: (cmd) =>
		data = cmd.split(" ")
		@socketNumber = data[1]
		@md5Hash = data[2]
		@clientIp = data[3]
		@clientPort = data[4]
		@timestamp = data[5]
		@runDefer.resolve(@_login())

	_onUserInfo: (cmd) =>
		user = {}
		tmp = cmd.split(" ");
		user.socket = tmp[0];
		user.login = tmp[1]
		user.ip = tmp[2]
		user.group = tmp[9]
		user.status = tmp[10].split(":")[0];
		user.connected = true
		user.isAtEpitech = /^10\./.test(user.ip);
		@logger.log(user)

	_onUserUpdate: (cmd) =>
		user = {}
		tmp = cmd.split(" ");
		tmp = tmp[1].split(":");
		user.socket = tmp[0];
		user.login = tmp[3].split("@")[0];
		user.ip = tmp[3].split("@")[1];
		user.group = tmp[4];
		user.isAtEpitech = /^10\./.test(user.ip);
		tmp = cmd.split(" | ")[1];
		if (tmp.indexOf("logout") != -1)
			user.connected = false
		else
			user.connected = true
		if (tmp.split(" ")[0] == "state")
			user.status = tmp.split(" ")[1].split(":")[0];
		@logger.log(user);

	_onPing: (cmd) =>
		@communicator.send cmd

	_onMessage: (cmd) =>
		if (@callback?) then @callback(cmd == "rep 002 -- cmd end")

	_onDisconnect: () =>
		@runDefer.reject("Netsoul: Connection Failed");
		Logger.error("Netsoul: Connection failed");
		setTimeout(() =>
			Logger.error("Netsoul: Trying to reconnect");
			@communicator.run()
		, 2000);



class NsWatch
	constructor: () ->
		@nsClients = [];

	run: (@logins) ->
		@nsClients = []
		logins = @logins.slice(0)
		while (logins.length > 0)
			s = logins.slice(0, 100)
			logins.splice(0, 100)
			@nsClients.push(new NsClient(s));

		p = 0;
		for client in @nsClients
			p = When.join(p, client.run())
		return p;

	getReport: () ->
		report = {}
		for client in @nsClients
			for login, status of client.getReport()
				isAtEpitech = false;
				isActif = false;
				for socketNum, infos of status.sockets
					if infos.isAtEpitech
						isAtEpitech = true;
					if infos.isActif
						isActif = true;
				report[login] = {connected: status.sockets.length != 0, isAtEpitech: isAtEpitech, isActif:isActif};
		return report;

module.exports	= NsWatch;
