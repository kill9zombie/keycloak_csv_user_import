require "logger"
require "http/client"

module KeycloakCsvUserImport

  # Just a shim class to make testing other
  # classes easier.  We can mock the returns of #get and #post
  # fairly easily.
  class HTTPClientShim

    def initialize(host, port, ssl_context)
      @ua = HTTP::Client.new(host, port, ssl_context)
    end

    def get(url, headers = nil)
      response = @ua.get(url, headers)

      {response.status_code, response.body}
    end

    def delete(url, headers = nil)
      response = @ua.delete(url, headers)

      {response.status_code, response.body}
    end

    def post(url, body, headers = nil)
      response = @ua.post(url, headers, body)

      {response.status_code, response.body}
    end

    def put(url, body, headers = nil)
      response = @ua.put(url, headers, body)

      {response.status_code, response.body}
    end

    def close
      @ua.close
    end

  end
end
