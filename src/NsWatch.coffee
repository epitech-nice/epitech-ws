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

EventEmitter = require('events').EventEmitter;
crypto = require('crypto');
Logger = require('./Logger.coffee');
net = require('net');
When = require('when');


class Communicator extends EventEmitter

	constructor: (@serverName, @serverPort) ->
		@client = null;
		@connected = false;
		@buffer = "";

	start: () ->
		@connected = true;
		@client = net.connect(@serverPort, @serverName, @onConnect);
		@client.setTimeout(1000 * 60 * 60);
		@client.setEncoding('ascii');
		@client.setTimeout(1000 * 60 * 15);
		@client.on('data', @onData);
		@client.on('error', @onError);
		@client.on('close', @onClose);
		@client.on('timeout', @onTimeout);

	stop: () ->
		@client.end();

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
		if !@logins[user.login]? then @logins[user.login] = {sockets:[]}
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

	clear: () ->
		for login,data of @logins
			@logins[login] = {sockets:[]};


class NsClient

	constructor: (server, port, @login, @password, logins) ->
		@communicator = new Communicator(server, port);
		@communicator.on('cmd', @_onCmd);
		@communicator.on('disconnect', @_onDisconnect);
		@logger = new NsClientLogger(logins);
		@callback = null;
		@runDefer = When.defer();
		@running = false;

	start: () ->
		@running = true;
		@communicator.start();
		return @runDefer.promise;

	stop: () ->
		@running = false;
		@communicator.stop();

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
			hash.update("#{@md5Hash}-#{@clientIp}/#{@clientPort}#{@password}");
			@_send("ext_user_log #{@login} #{hash.digest('hex')} none none").then () =>
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
		if (@running == false) then return;
		@runDefer.reject("Netsoul: Connection Failed");
		Logger.error("Netsoul: Connection failed");
		@logger.clear();
		setTimeout(() =>
			Logger.error("Netsoul: Trying to reconnect");
			@communicator.start()
		, 2000);



class NsWatch
	constructor: (@server, @port, @login, @password) ->
		@nsClients = [];

	start: (@logins) ->
		@nsClients = []
		logins = @logins.slice(0)
		while (logins.length > 0)
			s = logins.slice(0, 100)
			logins.splice(0, 100)
			@nsClients.push(new NsClient(@server, @port, @login, @password, s));

		p = 0;
		for client in @nsClients
			p = When.join(p, client.start())
		return p;

	stop: () ->
		for client in @nsClients
			client.stop();
		@nsClients = [];

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
