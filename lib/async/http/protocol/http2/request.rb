# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative '../request'
require_relative 'stream'

module Async
	module HTTP
		module Protocol
			module HTTP2
				# Typically used on the server side to represent an incoming request, and write the response.
				class Request < Protocol::Request
					class Stream < HTTP2::Stream
						def initialize(*)
							super
							
							@request = Request.new(self)
						end
						
						attr :request
						
						# Create a fake request on the server, with the given headers.
						def create_push_promise_stream(headers)
							stream = @connection.create_push_promise_stream(&Stream.method(:create))
							
							# This will ultimately enqueue the request to be processed by the server:
							stream.apply_headers(headers, false)
							
							return stream
						end
						
						def receive_headers(frame)
							apply_headers(super, frame.end_stream?)
						end
						
						def apply_headers(headers, end_stream)
							headers.each do |key, value|
								if key == SCHEME
									return send_failure(400, "Request scheme already specified") if @request.scheme
									
									@request.scheme = value
								elsif key == AUTHORITY
									return send_failure(400, "Request authority already specified") if @request.authority
									
									@request.authority = value
								elsif key == METHOD
									return send_failure(400, "Request method already specified") if @request.method
									
									@request.method = value
								elsif key == PATH
									return send_failure(400, "Request path already specified") if @request.path
									
									@request.path = value
								elsif key == PROTOCOL
									return send_failure(400, "Request protocol already specified") if @request.protocol
									
									@request.protocol = value
								elsif key == CONTENT_LENGTH
									return send_failure(400, "Request protocol already content length") if @length
									
									@length = Integer(value)
								elsif key.start_with? ':'
									return send_failure(400, "Invalid pseudo-header #{key}")
								else
									@request.headers.add(key, value)
								end
							end
							
							unless @request.valid?
								send_reset_stream(::Protocol::HTTP2::Error::PROTOCOL_ERROR)
							else
								# We only construct the input/body if data is coming.
								unless end_stream
									@input = Body::Writable.new(@length)
									@request.body = @input
								end
								
								# We are ready for processing:
								@connection.requests.enqueue(@request)
							end
							
							return headers
						end
					end
					
					def initialize(stream)
						super(nil, nil, nil, nil, VERSION, ::Protocol::HTTP::Headers.new)
						
						@stream = stream
					end
					
					attr :stream
					
					def valid?
						@scheme and @method and @path
					end
					
					def hijack?
						false
					end
					
					def push?
						@stream.connection.enable_push?
					end
					
					# @return [Stream] the promised stream, on which to send data.
					def push(path, headers = nil, scheme = @scheme, authority = @authority)
						raise ArgumentError, "Missing scheme!" unless scheme
						raise ArgumentError, "Missing authority!" unless authority
						
						push_headers = [
							[SCHEME, scheme],
							[METHOD, ::Protocol::HTTP::Methods::GET],
							[PATH, path],
							[AUTHORITY, authority]
						]
						
						if headers
							push_headers = Headers::Merged.new(
								push_headers,
								headers
							)
						end
						
						@stream.send_push_promise(push_headers)
					end
					
					NO_RESPONSE = [
						[STATUS, '500'],
					]
					
					def send_response(response)
						if response.nil?
							@stream.send_headers(nil, NO_RESPONSE, ::Protocol::HTTP2::END_STREAM)
						elsif response.body?
							pseudo_headers = [
								[STATUS, response.status],
							]
							
							if protocol = response.protocol
								pseudo_headers << [PROTOCOL, protocol]
							end
							
							if length = response.body.length
								pseudo_headers << [CONTENT_LENGTH, length]
							end
							
							headers = ::Protocol::HTTP::Headers::Merged.new(
								pseudo_headers,
								response.headers
							)
							
							@stream.send_headers(nil, headers)
							@stream.send_body(response.body)
						else
							headers = ::Protocol::HTTP::Headers::Merged.new([
								[STATUS, response.status],
							], response.headers)
							
							@stream.send_headers(nil, headers, ::Protocol::HTTP2::END_STREAM)
						end
					end
				end
			end
		end
	end
end
