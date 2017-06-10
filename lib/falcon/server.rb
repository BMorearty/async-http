# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/http/server'

module Falcon
	class Server
		def initialize(app, *args)
			super(args)
			
			@app = app
		end
		
		def handle_request(request, peer, address)
			request_path, query_string = request.path.split('?', 2)
			
			env = {
				'rack.version' => '2.0.0',
				
				'rack.input' => request,
				'rack.errors' => $stderr,
				
				# The HTTP request method, such as “GET” or “POST”. This cannot ever be an empty string, and so is always required.
				'REQUEST_METHOD' => request.method,
				
				# The initial portion of the request URL's “path” that corresponds to the application object, so that the application knows its virtual “location”. This may be an empty string, if the application corresponds to the “root” of the server.
				'SCRIPT_NAME' => '',
				
				# The remainder of the request URL's “path”, designating the virtual “location” of the request's target within the application. This may be an empty string, if the request URL targets the application root and does not have a trailing slash. This value may be percent-encoded when originating from a URL.
				'PATH_INFO' => request_path,
				
				# The portion of the request URL that follows the ?, if any. May be empty, but is always required!
				'QUERY_STRING' => query_string,
				
				# The server protocol, e.g. HTTP/1.1
				'SERVER_PROTOCOL' => request.version,
				
				# 'SERVER_NAME' => address.name,
				# 
				# 'SERVER_PORT' => address.
			}.merge(headers)
			
			@app.call(env)
		rescue
			[500, {}, [$!.inspect]]
		end
	end
end
