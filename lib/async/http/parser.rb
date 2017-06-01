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

module Async
	module HTTP
		class Parser
			HTTP_CONTENT_LENGTH = 'HTTP_CONTENT_LENGTH'.freeze
			
			def read_request(io)
				method, url, version = io.readline.split(/\s+/)
				
				headers = {}
				
				# Parsing headers:
				io.each do |line|
					if line =~ /([a-zA-Z\-]+):\s*(.+?)\s+/
						headers["HTTP_#{$1.tr('-', '_').upcase}"] = $2
					else
						break
					end
				end
				
				if content_length = headers[HTTP_CONTENT_LENGTH]
					body = io.read(Integer(content_length))
				end
				
				return method, url, version, headers, body
			end
		end
	end
end
