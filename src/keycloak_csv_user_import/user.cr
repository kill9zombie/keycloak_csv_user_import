
require "json"
require "./temporary_password"

module KeycloakCsvUserImport
  class User

    @username : String
    @first_name : String
    @last_name : String
    @attributes : Hash(String, String)
    @email : String
    @groups : Array(String)
    @enabled : Bool
    @credentials : Array(KeycloakCsvUserImport::TemporaryPassword)

    def initialize(@username, @first_name, @last_name, @email, @groups = ["student"], @attributes = {} of String => String, @enabled = true)
      @credentials = [TemporaryPassword.new]
    end


    JSON.mapping(
      username: String,
      first_name: {type: String, key: "firstName"},
      last_name: {type: String, key: "lastName"},
      attributes: Hash(String, String),
      email: String,
      groups: Array(String),
      enabled: Bool,
      credentials: Array(KeycloakCsvUserImport::TemporaryPassword)
    )
  end
end
