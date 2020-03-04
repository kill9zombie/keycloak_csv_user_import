require "logger"
require "http/params"

module KeycloakCsvUserImport

  class KeycloakAPIError < Exception; end

  class KeycloakAPIUnauthorizedError < Exception
    def initialize
      super("Unauthorized")
    end
  end

  class KeycloakAPI

    # 409 - conflict - Either the username or email address clashes with an existing user

    @realm : String
    @log : Logger
    @username : String
    @password : String

    @access_token = ""

    def initialize(@log, host, port, @username, @password, @realm, @ssl_verify = false)
      ssl_context = OpenSSL::SSL::Context::Client.new
      ssl_context.verify_mode = if @ssl_verify == false
                                  OpenSSL::SSL::VerifyMode::NONE
                                else
                                  OpenSSL::SSL::VerifyMode::PEER
                                end

      @http = HTTPClientShim.new(host, port, ssl_context)
      @groups_cache = [] of NamedTuple(id: String, name: String, path: String)
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
      elsif response[0] == 401
          raise KeycloakAPIUnauthorizedError.new
      else
        raise KeycloakAPIError.new("Could not authenticate: #{response}")
      end
    end

    def has_token?
      begin
        get_id_for_user(@username)
        true
      rescue KeycloakAPIUnauthorizedError
        nil
      end
    end

    # DELETE https://login.localnet:8443/auth/admin/realms/school/users/9c4cc933-94b3-40e4-9cc1-127caabf42a1/groups/7e1ba783-5b27-4169-937f-5dd6bc70a46b
    # Delete user from group


    def get_id_for_user(username : String)
      prefix = "#{self.class}#get_user_id :: "
      headers = HTTP::Headers.new
      headers.add("Content-Type", "application/json")
      headers.add("Authorization", "Bearer #{@access_token}")

      params = HTTP::Params.encode({username: username})
      @log.debug "#{prefix} fetching the ID for username: #{username}"
      response = @http.get("/auth/admin/realms/#{@realm}/users?" + params, headers)
      @log.debug "#{prefix} response: #{response}"
      if response[0] == 200
        response_body = JSON.parse(response[1])
        response_body[0]["id"].to_s
      elsif response[0] == 401
          raise KeycloakAPIUnauthorizedError.new
      else
        raise KeycloakAPIError.new("Could not find the ID for user: #{username}, #{response}")
      end
    end

    def get_all_groups
      prefix = "#{self.class}#get_user_id :: "
      headers = HTTP::Headers.new
      headers.add("Content-Type", "application/json")
      headers.add("Authorization", "Bearer #{@access_token}")

      response = @http.get("/auth/admin/realms/#{@realm}/groups", headers)
      @log.debug "#{prefix} response: #{response}"
      if response[0] == 200
        response_body = JSON.parse(response[1])
        response_body.as_a.map do |group|
          {id: group["id"].as_s, name: group["name"].as_s, path: group["path"].as_s}
        end
      elsif response[0] == 401
          raise KeycloakAPIUnauthorizedError.new
      else
        raise KeycloakAPIError.new("Could not list all groups: #{response}")
      end
    end

    def get_id_for_group?(groupname : String)
      if @groups_cache.any? {|x| x[:name] == groupname}
        @groups_cache.find(if_none: {id: nil}) {|x| x[:name] == groupname}[:id]
      else
        @groups_cache = get_all_groups
        @groups_cache.find(if_none: {id: nil}) {|x| x[:name] == groupname}[:id]
      end
    end

    def get_groups_for_userid(id : String)
      prefix = "#{self.class}#get_groups_for_userid :: "
      headers = HTTP::Headers.new
      headers.add("Content-Type", "application/json")
      headers.add("Authorization", "Bearer #{@access_token}")

      response = @http.get("/auth/admin/realms/#{@realm}/users/#{id}/groups", headers)
      @log.debug "#{prefix} response: #{response}"
      if response[0] == 200
        response_body = JSON.parse(response[1])
        response_body.as_a.map do |group|
          {id: group["id"].as_s, name: group["name"].as_s, path: group["path"].as_s}
        end
      elsif response[0] == 401
          raise KeycloakAPIUnauthorizedError.new
      else
        raise KeycloakAPIError.new("Could not find the groups for user ID: #{id}, #{response}")
      end
    end

    def delete_group_from_userid(groupid, userid)
      prefix = "#{self.class}#delete_groups_from_userid :: "
      headers = HTTP::Headers.new
      headers.add("Content-Type", "application/json")
      headers.add("Authorization", "Bearer #{@access_token}")

      response = @http.delete("/auth/admin/realms/#{@realm}/users/#{userid}/groups/#{groupid}", headers)
      @log.debug "#{prefix} response: #{response}"
      if response[0] == 204
        :ok
      elsif response[0] == 401
        raise KeycloakAPIUnauthorizedError.new
      else
        raise KeycloakAPIError.new("Could not delete group #{groupid} for user ID: #{userid}, #{response}")
      end
    end


    # PUT https://login.localnet:8443/auth/admin/realms/school/users/9c4cc933-94b3-40e4-9cc1-127caabf42a1/groups/be313ae0-a99a-4479-bfb4-6d24f913d8ee
    # {"realm":"school","userId":"9c4cc933-94b3-40e4-9cc1-127caabf42a1","groupId":"be313ae0-a99a-4479-bfb4-6d24f913d8ee"}
    def add_group_to_userid(groupid, userid)
      prefix = "#{self.class}#delete_groups_from_userid :: "
      headers = HTTP::Headers.new
      headers.add("Content-Type", "application/json")
      headers.add("Authorization", "Bearer #{@access_token}")
      body = {"realm" => @realm, "userId" => userid, "groupID" => groupid}.to_json

      response = @http.put("/auth/admin/realms/#{@realm}/users/#{userid}/groups/#{groupid}", body, headers)
      @log.debug "#{prefix} response: #{response}"
      if response[0] == 204
        :ok
      elsif response[0] == 401
        raise KeycloakAPIUnauthorizedError.new
      else
        raise KeycloakAPIError.new("Could not add group #{groupid} to user ID: #{userid}, #{response}")
      end
    end

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
      if has_token? == nil
        update_access_token
      end

      users.map do |user|
        response = add_user(user)
        case response[0]
        when 201
          @log.debug "User \"#{user.first_name} #{user.last_name}\" created OK"
          userid = get_id_for_user(user.username)
          @log.debug "Found user ID: #{userid} for user: #{user.username}"
          groups = get_groups_for_userid(userid)
          @log.debug "Found groups: #{groups} for user: #{user.username}"
          unless groups.empty?
            groups.each do |group|
              delete_group_from_userid(group[:id], userid)
              @log.debug "Deleted group: #{group} from user: #{user.username}"
            end
          end
          user.groups.each do |group_name|
            groupid = get_id_for_group?(group_name)
            if groupid == nil
              raise KeycloakAPIError.new("Could not find group ID for group \"#{group_name}\"")
            end

            add_group_to_userid(groupid, userid)
            @log.debug "Added group: #{group_name} to user: #{user.username}"
          end
          {user: user, created: true, message: "User \"#{user.first_name} #{user.last_name}\" created OK"}
        when 401
          # TODO
          update_access_token

        when 409
          # Username or email address already exist
          :todo

        else
        end
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
