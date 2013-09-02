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

fileConfig = require('./config.json');

class Config
	constructor: () ->
		@config = {}

	load: () ->
		@config = {server:{port: 4242}}
		for key,value of fileConfig
			@config[key] = value;

	get: (name) ->
		name = name.split(".")
		config = @config
		for t in name
			if (!config[t]?)
				return (null)
			config = config[t]
		return (config);

module.exports = new Config()