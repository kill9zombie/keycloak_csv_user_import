require "json"

module KeycloakCsvUserImport

  class TemporaryPassword
    @type : String
    @value : String
    @temporary : Bool

    def initialize(username)
      # See core/src/main/java/org/keycloak/representations/idm/CredentialRepresentation.java
      @type = "password"
      @temporary = true
      # @value = "test"
      @value = username.chars.shuffle.join
    end

    JSON.mapping(
      type: String,
      value: String,
      temporary: Bool
    )

  end
end
