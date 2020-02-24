require "logger"

module KeycloakCsvUserImport

  class KeycloakAPIError < Exception; end

  class KeycloakAPI

    # 409 - conflict - Either the username or email address clashes with an existing user

    @realm : String
    @log : Logger
    @username : String
    @password : String

    def initialize(@log, host, port, @username, @password, @realm, @ssl_verify = false)
      ssl_context = OpenSSL::SSL::Context::Client.new
      ssl_context.verify_mode = if @ssl_verify == false
                                  OpenSSL::SSL::VerifyMode::NONE
                                else
                                  OpenSSL::SSL::VerifyMode::PEER
                                end

      @http = HTTPClientShim.new(host, port, ssl_context)
      @access_token = ""
    end

    def update_access_token
      log_prefix = "#{self.class}#access_token :: "

      @log.debug("Refreshing access token")

      request_body = HTTP::Params.encode({"client_id" => "admin-cli",
                                       "grant_type" => "password",
                                       "username" => @username,
                                       "password" => @password})

      request_headers = HTTP::Headers.new
      request_headers.add("Content-Type", "application/x-www-form-urlencoded")

      response = @http.post("/auth/realms/#{@realm}/protocol/openid-connect/token", request_body, request_headers)
      if response[0] == 200
        access_token = Hash(String, (String|Int32)).from_json(response[1])
        @log.debug("#{log_prefix} Got access token: #{access_token["access_token"].to_s.[0..10]}...")
        @access_token = access_token["access_token"].to_s
        access_token["access_token"].to_s
      else
        raise KeycloakAPIError.new("Could not authenticate: #{response}")
      end


    end

    # TODO - max auth attempts
    def add_user(user : User)
      prefix = "#{self.class}#add_user :: "
      headers = HTTP::Headers.new
      headers.add("Content-Type", "application/json")
      headers.add("Authorization", "Bearer #{@access_token}")
      response = @http.post("/auth/admin/realms/#{@realm}/users", user.to_json, headers)
      @log.debug "#{prefix} adding #{user.username}, response: #{response}"
      response
    end

    def add_users(users : Nil)
      raise KeycloakAPIError.new("Caught nil users list in #{self.class}#add_users")
    end
    def add_users(users : Array(User))
      users.map do |user|
        response = add_user(user)
        if response[0] == 401
          update_access_token
          resp = add_user(user)
          {"user" => user, "response" => resp}
        else
          {"user" => user, "response" => response}
        end
      end
    end

  end

end
