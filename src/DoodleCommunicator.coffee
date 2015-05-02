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

Cache = require('./Cache.coffee');
HttpClient = require('./HttpClient.coffee');
moment = require('moment');

class DoodleCommunicator

    getPoll: (pollId) ->
        Cache.findOrInsert "DOODLE.#{pollId}", moment().add(5, 'm').toDate(), () =>
            return @_getPoll(pollId)

    _getPoll: (pollId) ->
        HttpClient.get("http://doodle.com/#{pollId}/admin").then (response) ->
            reg = new RegExp('({"poll":.*})\\);', 'm');
            res = reg.exec(response.data);
            if (not res?) then throw new Error("Cant parse info from doodle");
            data = JSON.parse(res[1]);
            data = data.poll
            options = []
            for option in data.optionsText
                options.push({
                    'name': option,
                    'count': 0
                });
            for participant in data.participants
                i = 0;
                for letter in participant.preferences
                    if letter == 'y'
                        options[i]['count']++;
                    i++;

            return options;


module.exports = new DoodleCommunicator();
