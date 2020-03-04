require "csv"
require "json"

module KeycloakCsvUserImport

  class OutputError < Exception; end
  class Output

    # Write the header line
    #  first name, last name, username, password, message
    # Find successes 201
    #  write CSV line
    # Find all the 409
    def write(io, results)
      csvbuilder = CSV::Builder.new(io)
      csvbuilder.row(header_line)

      rows = results.map do |result|
               user = result["user"]
               api_response = result["response"]

               user_row = user_row(api_response, user)
             end

      # Sort by status, then last name
      rows.sort_by {|x| [x[4], x[1]]}.each do |row|
        csvbuilder.row(row)
      end
    end

    def header_line
      ["first name", "last name", "username", "password", "status", "message"]
    end

    def user_row(api_response, user)
      raise OutputError.new("Unexpected API Response, expected {Int32, String}, got User!")
    end
    def user_row(api_response : {Int32, String}, user : KeycloakCsvUserImport::User)

      password, status, message = case api_response[0]
               when 201
                 [user.credentials[0].value, "OK", ""]
               when 409
                 ["", "Not created", get_message(api_response)]
               else
                 ["", "Error", get_message(api_response)]
               end


      [user.first_name, user.last_name, user.username, password, status, message]
    end

    def get_message(api_response)
      msg = JSON.parse(api_response[1])
      if msg.as_h.has_key?("errorMessage")
        msg["errorMessage"].as_s
      else
        ""
      end

    end

  end
end
