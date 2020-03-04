require "logger"
require "../spec_helper"
require "../../src/keycloak_csv_user_import/http_client_shim"
require "../../src/keycloak_csv_user_import/keycloak_api"


describe KeycloakCsvUserImport::KeycloakAPI do

  it "can find a user ID" do
    log = Logger.new(nil)
    api = KeycloakCsvUserImport::KeycloakAPI.new(log, "192.168.20.20", 8443, "alice", "test", "school")

    api.update_access_token
    id =  api.get_id_for_user("bobfl")
    # puts api.get_groups_for_userid(id)
    api.get_id_for_group?("School Adminssss").should eq nil
    api.get_id_for_group?("School Admins").should eq "be313ae0-a99a-4479-bfb4-6d24f913d8ee"

    puts api.add_group_to_userid("be313ae0-a99a-4479-bfb4-6d24f913d8ee", id)

  end

end
